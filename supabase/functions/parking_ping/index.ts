/**
 * POST /functions/v1/parking_ping
 *
 * マイコンから定期的に呼ぶ「自転車まだスタンドに居ます」通知。
 * issue_coupons は最後の ping から PRESENCE_TOLERANCE_SECONDS を超えた
 * デバイスへのクーポン発行をスキップする（在席チェック）。
 *
 * 入力:  { deviceId: string, seenAt?: string (ISO8601, 省略時は now) }
 * 出力:  { deviceId, lastSeenAt }
 *
 * 認証: service_role key（IoT は外部から service_role で叩く想定）。
 *
 * 推奨 ping 間隔: 30秒
 *   - constants.ts の PRESENCE_TOLERANCE_SECONDS (90秒) の 1/3
 *   - ネットワーク瞬断で 2回連続失敗しても許容できる余裕を確保
 */

import { handleCorsPreflight } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import { serviceClient } from "../_shared/supabase.ts";

interface PingBody {
  deviceId?: string;
  seenAt?: string;
}

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;

  if (req.method !== "POST") {
    return errorResponse(405, "invalid_request", "POST only");
  }

  let body: PingBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "invalid_request", "invalid JSON body");
  }

  const deviceId = body.deviceId?.trim();
  if (!deviceId) {
    return errorResponse(400, "invalid_request", "deviceId is required");
  }

  const seenAt = body.seenAt ?? new Date().toISOString();

  const supabase = serviceClient();
  const { data, error } = await supabase
    .from("devices")
    .update({ last_seen_at: seenAt })
    .eq("id", deviceId)
    .select("id, last_seen_at")
    .maybeSingle();

  if (error) {
    console.error("device update failed", error);
    return errorResponse(500, "internal_error", error.message);
  }
  if (!data) {
    return errorResponse(404, "device_not_found", `device ${deviceId} not found`);
  }

  return jsonResponse({ deviceId: data.id, lastSeenAt: data.last_seen_at }, 200);
});
