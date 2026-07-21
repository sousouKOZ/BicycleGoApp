/**
 * POST /functions/v1/notify_long_parking
 *
 * 長時間（デフォルト24時間）駐輪が続いているセッションのユーザーに警告 push を1回送る。
 * pg_cron から毎時呼び出される。
 *
 * 処理:
 *   1. status IN ('measuring','achieved','parked') かつ detected_at が
 *      LONG_PARK_WARN_SECONDS より前で、まだ警告していない（long_park_warned_at IS NULL）
 *      セッションを抽出
 *   2. 各ユーザーの fcm_token へ警告 push を送信（未設定/token無しは静かに skip）
 *   3. 送信成否に関わらず long_park_warned_at = now() を立てて再送を防ぐ（要件は「1回」）
 */

import { handleCorsPreflight } from "../_shared/cors.ts";
import { errorResponse, jsonResponse } from "../_shared/errors.ts";
import {
  isLocalInternalBypassEnabled,
  isServiceRoleRequest,
  serviceClient,
} from "../_shared/supabase.ts";
import { LONG_PARK_WARN_SECONDS } from "../_shared/constants.ts";
import { sendToToken } from "../_shared/fcm.ts";

Deno.serve(async (req) => {
  const preflight = handleCorsPreflight(req);
  if (preflight) return preflight;
  if (req.method !== "POST") {
    return errorResponse(405, "invalid_request", "POST only");
  }
  if (!isServiceRoleRequest(req) && !isLocalInternalBypassEnabled()) {
    return errorResponse(401, "unauthorized", "service_role bearer required");
  }

  const supabase = serviceClient();
  const cutoff = new Date(
    Date.now() - LONG_PARK_WARN_SECONDS * 1000,
  ).toISOString();

  type SessionRow = { id: string; user_id: string };

  const { data: sessions, error } = await supabase
    .from("parking_sessions")
    .select("id, user_id")
    .in("status", ["measuring", "achieved", "parked"])
    .lt("detected_at", cutoff)
    .is("long_park_warned_at", null)
    .not("user_id", "is", null)
    .limit(100);

  if (error) {
    console.error("[notify_long_parking] session query failed", error);
    return errorResponse(500, "internal_error", error.message);
  }

  const targets = (sessions ?? []) as SessionRow[];
  if (targets.length === 0) {
    return jsonResponse({ warned: 0 }, 200);
  }
  console.log(`[notify_long_parking] found ${targets.length} long-parked sessions`);

  let warned = 0;
  const errors: string[] = [];

  for (const session of targets) {
    // 1. 再送防止フラグを先に立てる（競合防止条件付き UPDATE）。
    //    送信失敗で毎時リトライし続けてスパムになるのを防ぐため、送信前に立てる。
    const nowIso = new Date().toISOString();
    const { data: updated, error: updateErr } = await supabase
      .from("parking_sessions")
      .update({ long_park_warned_at: nowIso })
      .eq("id", session.id)
      .is("long_park_warned_at", null)
      .select("id");
    if (updateErr) {
      errors.push(`session ${session.id}: flag update failed: ${updateErr.message}`);
      continue;
    }
    if (!updated || updated.length === 0) {
      // 他プロセスが既に警告済み → skip
      continue;
    }

    warned += 1;

    // 2. FCM push 送信。fcm_token 未登録 / FCM 未設定なら静かに skip。
    //    送信失敗はログに残すだけ（フラグは既に立てており再送しない方針）。
    const { data: userRow, error: userErr } = await supabase
      .from("users")
      .select("fcm_token")
      .eq("id", session.user_id)
      .maybeSingle();
    if (userErr) {
      console.error(`[FCM] users lookup failed for ${session.user_id}:`, userErr);
      continue;
    }
    const fcmToken = (userRow as { fcm_token: string | null } | null)?.fcm_token;
    if (!fcmToken) continue;

    const ok = await sendToToken(
      fcmToken,
      {
        title: "🚲 長時間の駐輪が続いています",
        body: "24時間以上駐輪されています。ご確認ください。",
      },
      {
        type: "long_park_warning",
        session_id: session.id,
      },
    );
    if (!ok) console.warn(`[FCM] long-park warning push failed for ${session.user_id}`);
  }

  if (errors.length > 0) {
    console.warn(`[notify_long_parking] ${errors.length} errors`, errors);
  }
  console.log(`[notify_long_parking] warned ${warned} sessions`);
  return jsonResponse({ warned, total: targets.length, errors }, 200);
});

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
