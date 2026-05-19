-- ============================================================
-- マイコンからの「在席通知」用カラム
-- ============================================================
-- マイコンは parking_detect / parking_ping を叩くたびに devices.last_seen_at
-- を更新する。issue_coupons がクーポンを発行する直前にこの値を確認し、
-- 「自転車を置いた直後に取り出してから15分待ち、不正にクーポンを得る」
-- 攻撃を防ぐ。
--
-- 在席通知が一定時間（PRESENCE_TOLERANCE_SECONDS、デフォルト 90秒）を
-- 超えて途絶している場合は、自転車が既に取り出されたとみなし、その
-- セッションへのクーポン発行をスキップする。

ALTER TABLE devices
  ADD COLUMN last_seen_at timestamptz;

-- issue_coupons の発行候補絞り込みで「在席チェック」を効率化するため、
-- last_seen_at に部分インデックスは作らず素のインデックスのみ。
-- devices テーブルは件数が少ないので影響軽微。
CREATE INDEX idx_devices_last_seen ON devices (last_seen_at);

COMMENT ON COLUMN devices.last_seen_at IS
  'マイコンから最後に在席通知（parking_detect / parking_ping）を受けた時刻。'
  'NULL は MCU が一度もアクセスしていない状態。';
