/**
 * POST /functions/v1/issue_exchange_coupon
 *
 * ポイント交換によるクーポン即時発行。
 *
 * 入力:  { exchangeItemId: string }
 * 出力:  Coupon（status='owned', distance_tier='exchange'）
 *
 * 認証: ユーザーJWT 必須
 *
 * 副作用（atomic、PL/pgSQL 関数 issue_exchange_coupon が実装）:
 *   - coupons INSERT
 *   - points.balance -= cost
 *   - point_transactions INSERT
 *
 * エラー:
 *   - exchange_item_not_found / insufficient_points
 */

import { handleCorsPreflight } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import { getCallerUserId, serviceClient } from "../_shared/supabase.ts";

interface ExchangeBody {
  exchangeItemId?: string;
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

  let body: ExchangeBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, "invalid_request", "invalid JSON body");
  }
  const exchangeItemId = body.exchangeItemId?.trim();
  if (!exchangeItemId) {
    return errorResponse(400, "invalid_request", "exchangeItemId is required");
  }

  const supabase = serviceClient();

  // PL/pgSQL 関数で原子的に発行（残高チェック → クーポン発行 → 残高減算 → 履歴記録）
  const { data, error } = await supabase.rpc("issue_exchange_coupon", {
    p_user_id: userId,
    p_exchange_item_id: exchangeItemId,
  });

  if (error) {
    // PL/pgSQL 側で RAISE EXCEPTION した場合、message に "exchange_item_not_found" 等が入る
    const message = error.message ?? "";
    if (message.includes("exchange_item_not_found")) {
      return errorResponse(
        404,
        "exchange_item_not_found",
        `exchange item ${exchangeItemId} not found or inactive`,
      );
    }
    if (message.includes("insufficient_points")) {
      return errorResponse(
        402,
        "insufficient_points",
        "not enough points for this exchange",
      );
    }
    console.error("RPC issue_exchange_coupon failed", error);
    return errorResponse(500, "internal_error", message);
  }

  return jsonResponse(data, 201);
});

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
