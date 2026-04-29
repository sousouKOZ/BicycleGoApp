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
