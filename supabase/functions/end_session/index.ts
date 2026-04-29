/**
 * POST /functions/v1/end_session
 *
 * 駐輪セッションの終了（出庫）。
 *
 * 入力:  { sessionId: string }
 * 出力:  ParkingSession（status='completed', exited_at=now）
 *
 * 副作用:
 *   - parking_lots.occupied -= 1（駐輪場の空き状況を更新）
 *
 * 認証: ユーザーJWT 必須（自分のセッションのみ終了可能）
 */

import { handleCorsPreflight } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import { getCallerUserId, serviceClient } from "../_shared/supabase.ts";

interface EndSessionBody {
  sessionId?: string;
}

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  if (req.method !== "POST") {
    return errorResponse(405, "invalid_request", "POST only");
  }

  const userId = await getCallerUserId(req);
  if (!userId) {
    return errorResponse(401, "unauthorized", "valid JWT required");
  }

  let body: EndSessionBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "invalid_request", "invalid JSON body");
  }
  const sessionId = body.sessionId?.trim();
  if (!sessionId) {
    return errorResponse(400, "invalid_request", "sessionId is required");
  }

  const supabase = serviceClient();

  // 1. セッション取得 + 所有者チェック
  const { data: session, error: fetchErr } = await supabase
    .from("parking_sessions")
    .select("id, user_id, device_id, status")
    .eq("id", sessionId)
    .maybeSingle();
  if (fetchErr) {
    return errorResponse(500, "internal_error", fetchErr.message);
  }
  if (!session) {
    return errorResponse(404, "session_not_found", "session not found");
  }
  if (session.user_id !== userId) {
    return errorResponse(403, "unauthorized", "not your session");
  }

  // 2. 既に completed なら冪等的に成功扱い（多重 tap 対策）
  if (session.status === "completed") {
    const { data: already } = await supabase
      .from("parking_sessions")
      .select("*")
      .eq("id", sessionId)
      .single();
    return jsonResponse(already, 200);
  }

  // 3. セッションを completed に
  const now = new Date().toISOString();
  const { data: updated, error: updateErr } = await supabase
    .from("parking_sessions")
    .update({ status: "completed", exited_at: now })
    .eq("id", sessionId)
    .neq("status", "completed")
    .select("*")
    .maybeSingle();
  if (updateErr) {
    return errorResponse(500, "internal_error", updateErr.message);
  }
  if (!updated) {
    // 直前に他プロセスが completed にした
    const { data: fallback } = await supabase
      .from("parking_sessions")
      .select("*")
      .eq("id", sessionId)
      .single();
    return jsonResponse(fallback, 200);
  }

  // 4. 駐輪場の occupied を -1（device → parking_lot を辿る）
  const { data: device } = await supabase
    .from("devices")
    .select("parking_lot_id")
    .eq("id", session.device_id)
    .maybeSingle();

  if (device?.parking_lot_id) {
    // SELECT してから UPDATE（read-modify-write）。MVP 用。
    // 本番では atomic decrement 用の PL/pgSQL 関数を作るのが望ましい。
    const { data: lot } = await supabase
      .from("parking_lots")
      .select("occupied")
      .eq("id", device.parking_lot_id)
      .maybeSingle();
    if (lot && lot.occupied > 0) {
      await supabase
        .from("parking_lots")
        .update({ occupied: lot.occupied - 1 })
        .eq("id", device.parking_lot_id);
    }
  }

  return jsonResponse(updated, 200);
});
