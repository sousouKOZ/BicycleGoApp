-- pg_cron から Edge Function を呼ぶヘルパーを「ローカル / クラウド両対応」に置き換え
--
-- 旧: ローカル Docker 内の `http://kong:8000` 固定 → クラウドでは host 解決失敗
-- 新: vault シークレット `edge_functions_url` と `edge_functions_service_role_key`
--     を優先して使い、無ければローカル Docker 用フォールバックを使う
--
-- ローカル開発時は vault シークレット未登録でも従来通り動作する。
-- クラウド本番では Studio → Database → Vault で以下2つを登録する:
--   - edge_functions_url:               https://<project_ref>.supabase.co/functions/v1
--   - edge_functions_service_role_key:  Project Settings → API の service_role key

CREATE OR REPLACE FUNCTION call_edge_function(function_name text)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, vault
AS $$
DECLARE
  v_base_url    text;
  v_service_key text;
  v_headers     jsonb;
  v_request_id  bigint;
BEGIN
  -- vault からシークレットを取得（無ければ NULL）
  SELECT decrypted_secret INTO v_base_url
    FROM vault.decrypted_secrets WHERE name = 'edge_functions_url';
  SELECT decrypted_secret INTO v_service_key
    FROM vault.decrypted_secrets WHERE name = 'edge_functions_service_role_key';

  -- ローカル開発時のフォールバック（Docker 内の Kong ゲートウェイ）
  IF v_base_url IS NULL OR v_base_url = '' THEN
    v_base_url := 'http://kong:8000/functions/v1';
  END IF;

  -- 認証ヘッダ: service_role key があれば Bearer 付与
  IF v_service_key IS NOT NULL AND v_service_key <> '' THEN
    v_headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_key
    );
  ELSE
    v_headers := jsonb_build_object('Content-Type', 'application/json');
  END IF;

  SELECT net.http_post(
    url := v_base_url || '/' || function_name,
    headers := v_headers,
    body := '{}'::jsonb,
    timeout_milliseconds := 10000
  ) INTO v_request_id;

  RETURN v_request_id;
END;
$$;

-- Copyright (c) 2026 小塩颯汰
-- Released under the MIT License.
