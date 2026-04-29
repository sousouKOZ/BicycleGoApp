/**
 * POST /functions/v1/redeem_coupon
 *
 * クーポン消込（スワイプto使用）。
 *
 * 入力:  { couponId: string }
 * 出力:  Coupon（status='used', used_at=now）
 *
 * 認証: ユーザーJWT 必須
 *
 * 冪等性: 既に used なら 409 already_used。expired なら 409 expired。
 *         アプリ側 docs/api_contract.md §2.5 と一致。
 */

import { handleCorsPreflight } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import { getCallerUserId, serviceClient } from "../_shared/supabase.ts";

interface RedeemBody {
  couponId?: string;
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

  let body: RedeemBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "invalid_request", "invalid JSON body");
  }
  const couponId = body.couponId?.trim();
  if (!couponId) {
    return errorResponse(400, "invalid_request", "couponId is required");
  }

  const supabase = serviceClient();

  // 1. クーポンを取得して所有者・状態チェック
  const { data: coupon, error: fetchErr } = await supabase
    .from("coupons")
    .select("id, user_id, status, expires_at")
    .eq("id", couponId)
    .maybeSingle();
  if (fetchErr) {
    return errorResponse(500, "internal_error", fetchErr.message);
  }
  if (!coupon) {
    return errorResponse(404, "session_not_found", "coupon not found");
  }
  if (coupon.user_id !== userId) {
    return errorResponse(403, "unauthorized", "not your coupon");
  }
  if (coupon.status === "used") {
    return errorResponse(409, "already_used", "coupon already used");
  }
  if (coupon.status === "expired" || new Date(coupon.expires_at) < new Date()) {
    return errorResponse(409, "expired", "coupon has expired");
  }

  // 2. owned のみ used に書き換え（条件付きで競合防止）
  const now = new Date().toISOString();
  const { data: updated, error: updateErr } = await supabase
    .from("coupons")
    .update({ status: "used", used_at: now })
    .eq("id", couponId)
    .eq("status", "owned")
    .select("*")
    .maybeSingle();
  if (updateErr) {
    return errorResponse(500, "internal_error", updateErr.message);
  }
  if (!updated) {
    // 直前の SELECT 後に他プロセスで already_used になった
    return errorResponse(409, "already_used", "coupon already used");
  }

  return jsonResponse(updated, 200);
});
