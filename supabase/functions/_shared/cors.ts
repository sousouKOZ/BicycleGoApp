/**
 * Edge Function 共通 CORS ヘッダ。
 * Flutter アプリ・ブラウザ両方からの呼び出しを許可。
 */

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

/** プリフライト OPTIONS リクエストへの即時 200 応答 */
export function handleCorsPreflight(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return null;
}
