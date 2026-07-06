-- 駐輪履歴が更新されない不具合の修正
--
-- 背景: 20260603090000_security_hardening.sql で devices の SELECT を
-- 「自分の *アクティブ* セッション（measuring/achieved/parked）が紐づく行」
-- に限定した。しかしセッションが completed になると device 行が読めなくなり、
-- アプリの getSessionHistory の devices → parking_lots embed が NULL となって
-- 履歴から完了セッションが全て消えていた（マイページの駐輪回数集計も同様）。
--
-- 対応: 状態を問わず「自分のセッションが紐づく device」まで読めるよう緩和する。
-- nfc_code の露出は自分が物理的にタッチしたことのある端末に限られるため、
-- security_hardening の意図（デバイスマスタの公開防止・列挙防止）は維持される。

DROP POLICY IF EXISTS devices_select_for_own_active_session ON devices;

CREATE POLICY devices_select_for_own_session ON devices
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM parking_sessions s
      WHERE s.device_id = devices.id
        AND s.user_id = auth.uid()
    )
  );
