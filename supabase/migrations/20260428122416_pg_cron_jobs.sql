-- pg_cron で Edge Function を定期呼び出しする設定
--
-- - issue_coupons:    15分達成セッションにクーポンを自律発行（毎分）
-- - expire_sessions:  5分超過の unauthenticated セッションを expired 化（毎分）
--
-- 呼び出しは pg_net の http_post 経由。
-- ローカル開発では Edge Function が --no-verify-jwt で動くため Authorization は不要。
-- 本番デプロイ時は vault.decrypted_secrets で service_role キーを引き、
-- Authorization ヘッダに付ける形に書き換える。

-- ============================================================
-- 1. 拡張機能を有効化
-- ============================================================

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- ============================================================
-- 2. Edge Function 呼び出しヘルパー
-- ============================================================
-- Edge Runtime は同一 Docker network 上の Kong ゲートウェイ経由で叩く。
-- Postgres コンテナから見ると http://kong:8000/functions/v1/<name>
-- がローカル開発のデフォルト URL。

CREATE OR REPLACE FUNCTION call_edge_function(function_name text)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  request_id bigint;
BEGIN
  SELECT net.http_post(
    url := 'http://kong:8000/functions/v1/' || function_name,
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := '{}'::jsonb,
    timeout_milliseconds := 10000
  ) INTO request_id;

  RETURN request_id;
END;
$$;

-- ============================================================
-- 3. cron スケジュール登録
-- ============================================================
-- 同じ名前で再実行すると重複登録になるので、まず既存をアンスケジュール。

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'issue_coupons') THEN
    PERFORM cron.unschedule('issue_coupons');
  END IF;
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'expire_sessions') THEN
    PERFORM cron.unschedule('expire_sessions');
  END IF;
END $$;

-- 毎分実行
SELECT cron.schedule(
  'issue_coupons',
  '* * * * *',
  $$ SELECT call_edge_function('issue_coupons'); $$
);

SELECT cron.schedule(
  'expire_sessions',
  '* * * * *',
  $$ SELECT call_edge_function('expire_sessions'); $$
);
