/**
 * POST /functions/v1/delete_account
 *
 * 呼び出しユーザー自身のアカウントを完全削除する（退会）。
 *
 * 入力:  なし
 * 出力:  { ok: true }
 *
 * 認証: ユーザーJWT 必須。自分自身（auth.uid()）のみ削除可能。
 *
 * 影響: auth.users を hard delete。FK ON DELETE CASCADE により
 *       public.users → coupons / points / point_transactions まで削除され、
 *       parking_sessions.user_id は SET NULL で匿名化される（履歴自体は残る）。
 *
 * App Store / Google Play の「アプリ内アカウント削除」要件に対応する。
 */

import { handleCorsPreflight } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import { getCallerUserId, serviceClient } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  if (req.method !== "POST") {
    return errorResponse(405, "method_not_allowed", "POST only");
  }

  const userId = await getCallerUserId(req);
  if (!userId) {
    return errorResponse(401, "unauthorized", "valid JWT required");
  }

  // service_role で auth ユーザーを hard delete。identities / sessions も公式 API が消す。
  const supabase = serviceClient();
  const { error } = await supabase.auth.admin.deleteUser(userId);
  if (error) {
    return errorResponse(500, "internal_error", error.message);
  }

  return jsonResponse({ ok: true }, 200);
});

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
