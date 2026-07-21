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
    .select("id, user_id, status, expires_at, store_id")
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

  // 3. レコメンドAPIにインクリメント通知 (非同期、エラーを投げない)
  try {
    const storeId = coupon.store_id;
    
    // 提携店舗の場合のみ（'exchange-'プレフィックス等ではない）、店舗カテゴリを取得して通知
    if (storeId && !storeId.startsWith('exchange-')) {
      const { data: storeData } = await supabase
        .from("stores")
        .select("category")
        .eq("id", storeId)
        .maybeSingle();

      const categoryName = storeData?.category;
      const pythonApiUrl = Deno.env.get("PYTHON_API_URL") || "http://host.docker.internal:5001";
      const pythonApiKey = Deno.env.get("PYTHON_API_KEY")?.trim();
      const pythonHeaders: Record<string, string> = {
        "Content-Type": "application/json",
      };
      if (pythonApiKey) {
        pythonHeaders.Authorization = `Bearer ${pythonApiKey}`;
      }

      // fire-and-forget
      fetch(`${pythonApiUrl}/api/v2/increment_visit`, {
        method: "POST",
        headers: pythonHeaders,
        body: JSON.stringify({
          user_id: userId,
          venue_id: storeId,
          category_name: categoryName
        })
      }).catch(err => console.error("[redeem_coupon] Failed to call increment_visit:", err));
    }
  } catch (err) {
    console.error("[redeem_coupon] Error preparing increment_visit:", err);
  }

  return jsonResponse(updated, 200);
});

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
