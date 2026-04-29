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
 *   2. 該当 deviceId の認証猶予内（5分以内）の unauthenticated セッションを検索
 *      - 無ければ auth_grace_expired
 *   3. user_id 紐付け + status='measuring' + authenticated_at=now()
 *   4. GPS 照合は実装しない（屋内・隣接スタンド誤判定対策で廃止済み）
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

  // 4. 5分以内の unauthenticated セッションを取得（無ければ作成 → IoT 未配備時の救済）
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

  let sessionId: string;

  if (pending) {
    sessionId = pending.id;
  } else {
    // IoT 未配備のため検知イベントが無い場合の救済:
    // 認証時に detected_at=now() の unauthenticated を即時作成する。
    // 本番では IoT 検知必須にしてこのフォールバックを撤去する想定。
    const newId = `ses-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
    const { data: created, error: createErr } = await supabase
      .from("parking_sessions")
      .insert({
        id: newId,
        device_id: deviceId,
        detected_at: new Date().toISOString(),
        status: "unauthenticated",
      })
      .select("id")
      .single();
    if (createErr) {
      return errorResponse(500, "internal_error", createErr.message);
    }
    sessionId = created.id;
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
    .eq("id", sessionId)
    .select("*")
    .single();

  if (updateErr) {
    return errorResponse(500, "internal_error", updateErr.message);
  }

  return jsonResponse(updated, 200);
});
