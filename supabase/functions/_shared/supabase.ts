/**
 * Supabase クライアントのファクトリ。
 *
 * 用途で2種類のクライアントを使い分ける:
 *
 * - userClient: 呼び出しユーザーの JWT を引き継ぐ。RLS ポリシーが適用される。
 *   通常のユーザー操作（クーポン消込・出庫など）で使用。
 *
 * - serviceClient: service_role キー使用。RLS をバイパスする。
 *   IoT 検知イベントの受信・cron による一括処理・複数ユーザーにまたがる処理で使用。
 */

import { createClient, SupabaseClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const DEVICE_INGEST_TOKEN = Deno.env.get("DEVICE_INGEST_TOKEN")?.trim() ?? "";

/** リクエストの Authorization ヘッダから JWT を引き継ぐ。RLS が効く。 */
export function userClient(req: Request): SupabaseClient {
  const authHeader = req.headers.get("Authorization") ?? "";
  return createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });
}

/** service_role キーで RLS をバイパス。IoT・cron 用。 */
export function serviceClient(): SupabaseClient {
  return createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
    auth: { persistSession: false },
  });
}

/** 認証済みユーザーの ID を JWT から取り出す。未認証なら null。 */
export async function getCallerUserId(req: Request): Promise<string | null> {
  const client = userClient(req);
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) return null;
  return data.user.id;
}

function bearerToken(req: Request): string | null {
  const authHeader = req.headers.get("Authorization") ?? "";
  const match = authHeader.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

/** service_role bearer で呼ばれているかを判定する。 */
export function isServiceRoleRequest(req: Request): boolean {
  return bearerToken(req) === SUPABASE_SERVICE_ROLE_KEY;
}

/**
 * IoT ingest 用の認可判定。
 *
 * マイコンへ service_role key を配るのは危険なので、通常は
 * DEVICE_INGEST_TOKEN を Authorization: Bearer ... で送る。
 * 管理ジョブや手動運用では service_role bearer も許可する。
 */
export function isDeviceIngestRequest(req: Request): boolean {
  const token = bearerToken(req);
  if (token === SUPABASE_SERVICE_ROLE_KEY) return true;
  return DEVICE_INGEST_TOKEN !== "" && token === DEVICE_INGEST_TOKEN;
}

/**
 * ローカル pg_cron など、認可ヘッダをまだ注入できない開発環境だけで使う逃げ道。
 * 本番ではこの環境変数を設定しない。
 */
export function isLocalInternalBypassEnabled(): boolean {
  return Deno.env.get("ALLOW_UNAUTHENTICATED_INTERNAL_JOBS") === "true";
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
