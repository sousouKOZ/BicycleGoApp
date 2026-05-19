/**
 * POST /functions/v1/parking_detect
 *
 * IoT デバイスから「自転車を検知した」イベントを受け取り、
 * 認証待ちの `parking_session` を作成する。
 *
 * 入力:  { deviceId: string, detectedAt: string (ISO8601) }
 * 出力:  ParkingSession（status='unauthenticated' or 既存の pending）
 *
 * 認証: service_role key（IoT は外部から service_role で叩く想定）。
 *        開発時は localhost で誰でも呼べる。
 */

import { handleCorsPreflight } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import { serviceClient } from "../_shared/supabase.ts";

interface DetectBody {
  deviceId?: string;
  detectedAt?: string;
}

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return errorResponse(405, "invalid_request", "POST only");
  }

  let body: DetectBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "invalid_request", "invalid JSON body");
  }

  const deviceId = body.deviceId?.trim();
  const detectedAt = body.detectedAt;
  if (!deviceId || !detectedAt) {
    return errorResponse(
      400,
      "invalid_request",
      "deviceId and detectedAt are required",
    );
  }

  const supabase = serviceClient();

  // 1. デバイス存在確認
  const { data: device, error: deviceErr } = await supabase
    .from("devices")
    .select("id")
    .eq("id", deviceId)
    .maybeSingle();
  if (deviceErr) {
    console.error("device lookup failed", deviceErr);
    return errorResponse(500, "internal_error", deviceErr.message);
  }
  if (!device) {
    return errorResponse(404, "device_not_found", `device ${deviceId} not found`);
  }

  // 2. 同 deviceId の既存 unauthenticated セッションがあれば返す（重複検知の冪等性）
  const { data: existing, error: existingErr } = await supabase
    .from("parking_sessions")
    .select("*")
    .eq("device_id", deviceId)
    .eq("status", "unauthenticated")
    .order("detected_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  if (existingErr) {
    console.error("existing session lookup failed", existingErr);
    return errorResponse(500, "internal_error", existingErr.message);
  }
  if (existing) {
    // 既存セッション返却時も在席は更新する（冪等な検知通知＝在席シグナル）。
    await supabase
      .from("devices")
      .update({ last_seen_at: detectedAt })
      .eq("id", deviceId);
    return jsonResponse(existing, 200);
  }

  // 3. 新規セッション作成
  const sessionId = `ses-${Date.now()}-${crypto.randomUUID().slice(0, 8)}`;
  const { data: created, error: insertErr } = await supabase
    .from("parking_sessions")
    .insert({
      id: sessionId,
      device_id: deviceId,
      detected_at: detectedAt,
      status: "unauthenticated",
    })
    .select("*")
    .single();

  if (insertErr) {
    console.error("session insert failed", insertErr);
    return errorResponse(500, "internal_error", insertErr.message);
  }

  // 検知も「在席通知」の一種として devices.last_seen_at を更新。
  // これにより最初の検知直後に issue_coupons が在席チェックを掛けても通る。
  // 失敗してもクーポン発行ロジック自体は parking_ping で別途維持されるためログだけ残す。
  const { error: seenErr } = await supabase
    .from("devices")
    .update({ last_seen_at: detectedAt })
    .eq("id", deviceId);
  if (seenErr) {
    console.error("devices.last_seen_at update failed", seenErr);
  }

  return jsonResponse(created, 201);
});
