/**
 * POST /functions/v1/acknowledge_earned_coupon
 *
 * クーポン獲得画面（CouponEarnedPage）を確認済みにする。
 * セッションを `achieved`（クーポン発行直後・未確認）から
 * `parked`（クーポン確認済み・自転車はまだスタンドにある）へ進める。
 *
 * これを呼ばないと、サーバ上のセッションが `achieved` のまま残り、
 * アプリ起動のたびに home_shell が獲得画面を再表示してしまう。
 *
 * 入力:  { sessionId: string }
 * 出力:  ParkingSession（status='parked'）
 *
 * 認証: ユーザーJWT 必須（自分のセッションのみ）
 *
 * 冪等性: 既に achieved 以外（parked/completed/expired 等）なら現在の行を
 *         そのまま返す。多重 tap・再送でも安全。
 */

import { handleCorsPreflight } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import { getCallerUserId, serviceClient } from "../_shared/supabase.ts";

interface AcknowledgeBody {
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

  let body: AcknowledgeBody;
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
    .select("id, user_id, status")
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

  // 2. achieved 以外なら確認済みとして冪等的に現在の行を返す
  if (session.status !== "achieved") {
    const { data: already } = await supabase
      .from("parking_sessions")
      .select("*")
      .eq("id", sessionId)
      .single();
    return jsonResponse(already, 200);
  }

  // 3. achieved → parked（条件付き UPDATE で競合を防止）
  const { data: updated, error: updateErr } = await supabase
    .from("parking_sessions")
    .update({ status: "parked" })
    .eq("id", sessionId)
    .eq("status", "achieved")
    .select("*")
    .maybeSingle();
  if (updateErr) {
    return errorResponse(500, "internal_error", updateErr.message);
  }
  if (!updated) {
    // 直前に他プロセスが status を進めた → 現在の行を返す
    const { data: fallback } = await supabase
      .from("parking_sessions")
      .select("*")
      .eq("id", sessionId)
      .single();
    return jsonResponse(fallback, 200);
  }

  return jsonResponse(updated, 200);
});

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
