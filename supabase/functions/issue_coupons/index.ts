/**
 * POST /functions/v1/issue_coupons
 *
 * 15分達成判定 + クーポン自律発行のスケジュールジョブ。
 * pg_cron から60秒ごとに呼び出される。
 *
 * 処理:
 *   1. status='measuring' で authenticated_at + 15分 を超えたセッションを抽出
 *   2. 各セッションの駐輪場 → 重み付きランダムで店舗選定
 *   3. クーポン発行 + session を 'achieved' に + 10pt 加算
 *   4. 件数を返す（push 通知は Phase 4 で追加）
 */

import { handleCorsPreflight } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import { serviceClient } from "../_shared/supabase.ts";
import {
  EARN_COUPON_VALIDITY_DAYS,
  EARN_POINTS_PER_SESSION,
  EARN_THRESHOLD_SECONDS,
} from "../_shared/constants.ts";
import {
  distanceTierFor,
  pickStoreWeighted,
} from "../_shared/recommendation.ts";
import type { ParkingLot, Store } from "../_shared/types.ts";

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  const supabase = serviceClient();

  // 1. 達成済み（15分超過 + 未発行）の measuring セッションを抽出
  const cutoff = new Date(
    Date.now() - EARN_THRESHOLD_SECONDS * 1000,
  ).toISOString();

  const { data: sessions, error: queryErr } = await supabase
    .from("parking_sessions")
    .select("id, user_id, device_id")
    .eq("status", "measuring")
    .is("issued_coupon_id", null)
    .lte("authenticated_at", cutoff)
    .not("user_id", "is", null)
    .limit(100);

  if (queryErr) {
    console.error("measuring sessions query failed", queryErr);
    return errorResponse(500, "internal_error", queryErr.message);
  }

  if (!sessions || sessions.length === 0) {
    return jsonResponse({ issued: 0, message: "no eligible sessions" }, 200);
  }

  type SessionRow = { id: string; user_id: string; device_id: string };
  const typedSessions = sessions as SessionRow[];

  // 2. デバイス → 駐輪場 のマップを作成（複数セッションが同じデバイスを使う可能性あり）
  const deviceIds = [...new Set(typedSessions.map((s: SessionRow) => s.device_id))];
  const { data: devices, error: devErr } = await supabase
    .from("devices")
    .select("id, parking_lot_id")
    .in("id", deviceIds);
  if (devErr || !devices) {
    return errorResponse(500, "internal_error", devErr?.message ?? "no devices");
  }
  type DeviceRow = { id: string; parking_lot_id: string };
  const typedDevices = devices as DeviceRow[];
  const deviceToParkingLotId = new Map<string, string>(
    typedDevices.map((d: DeviceRow) => [d.id, d.parking_lot_id]),
  );

  // 3. 駐輪場マスタを取得
  const parkingLotIds = [...new Set(typedDevices.map((d: DeviceRow) => d.parking_lot_id))];
  const { data: parkingLots, error: lotErr } = await supabase
    .from("parking_lots")
    .select("id, name, lat, lng, capacity, occupied, price_yen_per_day, updated_at")
    .in("id", parkingLotIds);
  if (lotErr || !parkingLots) {
    return errorResponse(500, "internal_error", lotErr?.message ?? "no lots");
  }
  const parkingLotMap = new Map<string, ParkingLot>(
    (parkingLots as ParkingLot[]).map((p) => [p.id, p]),
  );

  // 4. 全店舗を1回だけ取得（推薦ロジックで使う）
  const { data: stores, error: storesErr } = await supabase
    .from("stores")
    .select("id, name, category, lat, lng, benefit, recommend_weight");
  if (storesErr || !stores) {
    return errorResponse(500, "internal_error", storesErr?.message ?? "no stores");
  }

  let issued = 0;
  const errors: string[] = [];

  for (const session of sessions) {
    const parkingLotId = deviceToParkingLotId.get(session.device_id);
    if (!parkingLotId) {
      errors.push(`session ${session.id}: device ${session.device_id} not found`);
      continue;
    }
    const parkingLot = parkingLotMap.get(parkingLotId);
    if (!parkingLot) {
      errors.push(`session ${session.id}: parking lot ${parkingLotId} not found`);
      continue;
    }

    // 店舗を選定
    const store = pickStoreWeighted(
      parkingLot.lat,
      parkingLot.lng,
      stores as Store[],
    );
    const tier = distanceTierFor(parkingLot.lat, parkingLot.lng, store);

    const couponId = `cp-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
    const now = new Date();
    const expiresAt = new Date(
      now.getTime() + EARN_COUPON_VALIDITY_DAYS * 24 * 60 * 60 * 1000,
    );

    // a) クーポン作成
    const { error: couponErr } = await supabase.from("coupons").insert({
      id: couponId,
      user_id: session.user_id,
      store_id: store.id,
      store_name: store.name,
      title: `15分駐輪達成！${store.name}で使える`,
      benefit: store.benefit,
      issued_at: now.toISOString(),
      expires_at: expiresAt.toISOString(),
      status: "owned",
      distance_tier: tier,
    });
    if (couponErr) {
      errors.push(`session ${session.id}: coupon insert failed: ${couponErr.message}`);
      continue;
    }

    // b) セッションを achieved に（競合防止条件付き UPDATE）
    const { data: updated, error: sessionErr } = await supabase
      .from("parking_sessions")
      .update({
        status: "achieved",
        issued_coupon_id: couponId,
      })
      .eq("id", session.id)
      .eq("status", "measuring")
      .is("issued_coupon_id", null)
      .select("id");
    if (sessionErr || !updated || updated.length === 0) {
      // 既に他プロセスが更新済み → 自分が作ったクーポンは余計なので削除
      await supabase.from("coupons").delete().eq("id", couponId);
      errors.push(
        `session ${session.id}: race condition or update failed (rolled back coupon)`,
      );
      continue;
    }

    // c) ポイント取引履歴
    const { error: txErr } = await supabase.from("point_transactions").insert({
      user_id: session.user_id,
      delta: EARN_POINTS_PER_SESSION,
      kind: "earn",
      related_session_id: session.id,
      note: "15分駐輪達成",
    });
    if (txErr) {
      errors.push(`session ${session.id}: tx insert failed: ${txErr.message}`);
    }

    // d) 残高加算（add_points RPC で原子的に処理 / race condition 対策）
    const { error: pointsErr } = await supabase.rpc("add_points", {
      p_user_id: session.user_id,
      p_delta: EARN_POINTS_PER_SESSION,
    });
    if (pointsErr) {
      errors.push(`session ${session.id}: add_points failed: ${pointsErr.message}`);
    }

    issued += 1;
    console.log(
      `issued ${couponId} for session ${session.id} (store=${store.name}, tier=${tier})`,
    );

    // TODO Phase 4: ここで FCM push を送る
  }

  return jsonResponse({ issued, total: sessions.length, errors }, 200);
});
