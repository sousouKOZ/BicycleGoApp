/**
 * POST /functions/v1/parking_auth
 *
 * アプリから NFC スキャン後に呼び出され、駐輪セッションを認証する。
 *
 * 入力:  { deviceId: string }
 * 出力:  ParkingSession（status='measuring'）
 *
 * 認証: ユーザーJWT 必須。Authorization ヘッダから userId を解決。
 *
 * 処理ロジック:
 *   1. JWT から userId を取得
 *   2. ユーザーが既にアクティブなセッション（measuring/achieved/parked）を
 *      持っていれば already_active で拒否（1ユーザー同時1駐輪。二重セッション・
 *      二重クーポン防止の最終防衛線。クライアントにもガードはあるが信用しない）
 *   3. 該当 deviceId の認証猶予内（5分以内）の unauthenticated セッションを検索
 *      - 無ければ auth_grace_expired
 *   4. user_id 紐付け + status='measuring' + authenticated_at=now()
 *   5. GPS 照合は実装しない（屋内・隣接スタンド誤判定対策で廃止済み）
 */

import { handleCorsPreflight } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import { getCallerUserId, serviceClient } from "../_shared/supabase.ts";
import { AUTH_GRACE_SECONDS } from "../_shared/constants.ts";

interface AuthBody {
  deviceId?: string;
}

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return errorResponse(405, "invalid_request", "POST only");
  }

  // 1. ユーザー認証
  const userId = await getCallerUserId(req);
  if (!userId) {
    return errorResponse(401, "unauthorized", "valid JWT required");
  }

  // 2. ボディ
  let body: AuthBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "invalid_request", "invalid JSON body");
  }
  const deviceId = body.deviceId?.trim();
  if (!deviceId) {
    return errorResponse(400, "invalid_request", "deviceId is required");
  }

  // 以降は service_role でデータ更新する（RLS バイパス）
  const supabase = serviceClient();

  // 3. デバイス存在確認
  const { data: device, error: deviceErr } = await supabase
    .from("devices")
    .select("id")
    .eq("id", deviceId)
    .maybeSingle();
  if (deviceErr) {
    return errorResponse(500, "internal_error", deviceErr.message);
  }
  if (!device) {
    return errorResponse(404, "device_not_found", `device ${deviceId} not found`);
  }

  // 3.5 同時駐輪は不可。ユーザーが既にアクティブなセッション
  //     （measuring/achieved/parked）を持っていれば認証を拒否する。
  //     これを怠ると 1 ユーザーが複数の measuring を同時に持ち、issue_coupons が
  //     セッション毎にクーポン＋ポイントを発行してしまう（二重取得）。
  //     クライアント側にもガードはあるが、デモのモック検知やアプリ再起動で
  //     回避され得るため、サーバーを最終防衛線とする。
  const { data: activeOwn, error: activeOwnErr } = await supabase
    .from("parking_sessions")
    .select("id")
    .eq("user_id", userId)
    .in("status", ["measuring", "achieved", "parked"])
    .limit(1)
    .maybeSingle();
  if (activeOwnErr) {
    return errorResponse(500, "internal_error", activeOwnErr.message);
  }
  if (activeOwn) {
    return errorResponse(
      409,
      "already_active",
      "user already has an active parking session",
    );
  }

  // 4. 5分以内の unauthenticated セッションを取得。MCU が parking_detect で
  //    作成済みの行のみが正規の証拠。
  const graceCutoff = new Date(
    Date.now() - AUTH_GRACE_SECONDS * 1000,
  ).toISOString();

  const { data: pending, error: pendingErr } = await supabase
    .from("parking_sessions")
    .select("*")
    .eq("device_id", deviceId)
    .eq("status", "unauthenticated")
    .gte("detected_at", graceCutoff)
    .order("detected_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (pendingErr) {
    return errorResponse(500, "internal_error", pendingErr.message);
  }
  if (!pending) {
    // MCU 検知が無いのか、検知はあったが認証猶予を超過したのかを区別する。
    // 直近30分以内に expired または猶予超過した unauthenticated が同じデバイス
    // で見つかれば「タッチが遅かった」、何も無ければ「そもそも検知が無い」。
    const lookback = new Date(Date.now() - 30 * 60 * 1000).toISOString();
    // 1. 直近30分以内の expired を探す
    const { data: expiredStale } = await supabase
      .from("parking_sessions")
      .select("id")
      .eq("device_id", deviceId)
      .eq("status", "expired")
      .gte("detected_at", lookback)
      .limit(1)
      .maybeSingle();

    // 2. 直近30分以内で猶予を超過した unauthenticated を探す
    const { data: unauthStale } = await supabase
      .from("parking_sessions")
      .select("id")
      .eq("device_id", deviceId)
      .eq("status", "unauthenticated")
      .gte("detected_at", lookback)
      .lt("detected_at", graceCutoff)
      .limit(1)
      .maybeSingle();

    if (expiredStale || unauthStale) {
      return errorResponse(
        410,
        "auth_grace_expired",
        "detection found but auth grace window has passed",
      );
    }
    return errorResponse(
      410,
      "no_recent_detection",
      "no parking_detect event for this device within recent window",
    );
  }

  // 5. 認証成立 → measuring に遷移
  const now = new Date().toISOString();
  const { data: updated, error: updateErr } = await supabase
    .from("parking_sessions")
    .update({
      user_id: userId,
      authenticated_at: now,
      status: "measuring",
    })
    .eq("id", pending.id)
    .select("*")
    .single();

  if (updateErr) {
    return errorResponse(500, "internal_error", updateErr.message);
  }

  return jsonResponse(updated, 200);
});
