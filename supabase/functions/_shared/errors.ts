/**
 * エラーレスポンス共通フォーマット。
 *
 * docs/api_contract.md §3 の例外コードと一致させる。
 * クライアント側 (lib/core/api/api_exceptions.dart) はこの code フィールドで分岐する。
 */

import { corsHeaders } from "./cors.ts";

export type ErrorCode =
  | "device_not_found"
  | "session_not_found"
  | "auth_grace_expired"
  | "already_used"
  | "expired"
  | "insufficient_points"
  | "exchange_item_not_found"
  | "unauthorized"
  | "invalid_request"
  | "internal_error";

export function errorResponse(
  status: number,
  code: ErrorCode,
  message?: string,
): Response {
  return new Response(
    JSON.stringify({ code, message: message ?? code }),
    {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
