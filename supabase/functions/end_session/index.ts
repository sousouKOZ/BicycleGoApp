/**
 * POST /functions/v1/end_session
 *
 * 駐輪セッションの終了（出庫 / 計測中止）。
 *
 * 入力:  { sessionId: string }
 * 出力:  ParkingSession
 *
 * ステータス遷移（呼び出し時点の status で分岐）:
 *   measuring          → cancelled  （15分達成前のユーザー手動中止。クーポン未発行）
 *   achieved / parked  → completed  （クーポン獲得済みの正常出庫）
 *   その他（終端）      → 何もしない（冪等。現在の行をそのまま返す）
 *
 * 副作用:
 *   - parking_lots.occupied -= 1（自転車を出すため空き状況を更新。cancelled/completed 共通）
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

  // 2. 既に終端（completed / cancelled / expired）なら冪等的に成功扱い（多重 tap 対策）
  const terminalStatuses = ["completed", "cancelled", "expired"];
  if (terminalStatuses.includes(session.status)) {
    const { data: already } = await supabase
      .from("parking_sessions")
      .select("*")
      .eq("id", sessionId)
      .single();
    return jsonResponse(already, 200);
  }

  // 3. 呼び出し時点の status で遷移先を決定。
  //    measuring（15分達成前の手動中止）は cancelled、
  //    achieved / parked（クーポン獲得済みの出庫）は completed。
  const nextStatus = session.status === "measuring" ? "cancelled" : "completed";

  const now = new Date().toISOString();
  const { data: updated, error: updateErr } = await supabase
    .from("parking_sessions")
    .update({ status: nextStatus, exited_at: now })
    .eq("id", sessionId)
    .eq("status", session.status) // 楽観ロック: 直前に他プロセスが変えていれば skip
    .select("*")
    .maybeSingle();
  if (updateErr) {
    return errorResponse(500, "internal_error", updateErr.message);
  }
  if (!updated) {
    // 直前に他プロセス（cron 達成判定 / マイコン出庫検知）が status を変えた
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
    // decrement_parking_occupied RPC で原子的に -1（race condition 対策）
    const { error: decErr } = await supabase.rpc("decrement_parking_occupied", {
      p_parking_lot_id: device.parking_lot_id,
    });
    if (decErr) {
      console.error("decrement_parking_occupied failed", decErr);
    }
  }

  return jsonResponse(updated, 200);
});

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
