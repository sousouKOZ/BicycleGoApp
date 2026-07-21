/**
 * POST /functions/v1/expire_sessions
 *
 * 認証猶予（5分）を超過した unauthenticated セッションを expired に変更するクリーンナップ。
 * pg_cron から60秒ごとに呼び出される。
 *
 * 処理:
 *   - status='unauthenticated' AND detected_at < now() - 5分 を一括で expired に UPDATE
 */

import { handleCorsPreflight } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import {
  isLocalInternalBypassEnabled,
  isServiceRoleRequest,
  serviceClient,
} from "../_shared/supabase.ts";
import { AUTH_GRACE_SECONDS } from "../_shared/constants.ts";

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  if (req.method !== "POST") {
    return errorResponse(405, "invalid_request", "POST only");
  }
  if (!isServiceRoleRequest(req) && !isLocalInternalBypassEnabled()) {
    return errorResponse(
      401,
      "unauthorized",
      "service_role bearer required",
    );
  }

  const supabase = serviceClient();
  const cutoff = new Date(
    Date.now() - AUTH_GRACE_SECONDS * 1000,
  ).toISOString();

  const { data: expired, error } = await supabase
    .from("parking_sessions")
    .update({ status: "expired" })
    .eq("status", "unauthenticated")
    .lt("detected_at", cutoff)
    .select("id");

  if (error) {
    console.error("expire update failed", error);
    return errorResponse(500, "internal_error", error.message);
  }

  const count = expired?.length ?? 0;
  if (count > 0) {
    console.log(`expired ${count} stale sessions`);
  }
  return jsonResponse({ expired: count }, 200);
});

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
