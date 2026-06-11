-- 24時間以上駐輪の警告通知機能
--
-- 長時間駐輪が続くセッションのユーザーに警告 push を1回送る。
-- 送信は Edge Function notify_long_parking が担当し、pg_cron が毎時呼び出す。
--
-- このマイグレーションは:
--   1. 再送防止カラム long_park_warned_at を parking_sessions に追加
--   2. cron スキャン用の partial index を追加
--   3. notify_long_parking を毎時実行する cron ジョブを登録

-- ============================================================
-- 1. 再送防止カラム
-- ============================================================
-- 警告 push を送ったら now() を立てる。NULL = 未警告。
-- 「1セッションあたり1回だけ」警告するための冪等キー。

ALTER TABLE parking_sessions
  ADD COLUMN long_park_warned_at timestamptz;

-- ============================================================
-- 2. cron スキャン用 partial index
-- ============================================================
-- notify_long_parking が「物理的に自転車が置かれていて未警告」のセッションを
-- detected_at で絞り込むためのインデックス。
-- initial_schema.sql の idx_sessions_pending_auth / idx_sessions_pending_earn と同じ流儀。

CREATE INDEX idx_sessions_long_park_pending
  ON parking_sessions (detected_at)
  WHERE status IN ('measuring', 'achieved', 'parked')
    AND long_park_warned_at IS NULL;

-- ============================================================
-- 3. cron スケジュール登録（毎時）
-- ============================================================
-- 24h しきい値に対して毎分は過剰なので毎時（毎時0分）に実行。
-- call_edge_function は cron_helper_for_cloud.sql でローカル/クラウド両対応済み。

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'notify_long_parking') THEN
    PERFORM cron.unschedule('notify_long_parking');
  END IF;
END $$;

SELECT cron.schedule(
  'notify_long_parking',
  '0 * * * *',
  $$ SELECT call_edge_function('notify_long_parking'); $$
);
