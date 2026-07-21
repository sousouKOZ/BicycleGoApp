-- Security hardening for client-facing roles.
--
-- Keep business side effects behind Edge Functions. The application uses
-- service_role inside Edge Functions for these operations, so authenticated
-- clients do not need direct UPDATE policies or SECURITY DEFINER RPC access.

-- parking_sessions / coupons are mutated through Edge Functions only.
DROP POLICY IF EXISTS sessions_update_own_checkout ON parking_sessions;
DROP POLICY IF EXISTS coupons_redeem_own ON coupons;

-- Device rows include NFC identifiers and should not be public master data.
-- The app only needs to resolve the device for the caller's active session.
DROP POLICY IF EXISTS devices_select_all ON devices;
CREATE POLICY devices_select_for_own_active_session ON devices
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM parking_sessions s
      WHERE s.device_id = devices.id
        AND s.user_id = auth.uid()
        AND s.status IN ('measuring', 'achieved', 'parked')
    )
  );

-- SECURITY DEFINER helpers bypass RLS. Do not expose them to client roles.
REVOKE ALL ON FUNCTION add_points(uuid, int) FROM PUBLIC;
REVOKE ALL ON FUNCTION add_points(uuid, int) FROM anon;
REVOKE ALL ON FUNCTION add_points(uuid, int) FROM authenticated;
GRANT EXECUTE ON FUNCTION add_points(uuid, int) TO service_role;

REVOKE ALL ON FUNCTION decrement_parking_occupied(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION decrement_parking_occupied(text) FROM anon;
REVOKE ALL ON FUNCTION decrement_parking_occupied(text) FROM authenticated;
GRANT EXECUTE ON FUNCTION decrement_parking_occupied(text) TO service_role;

REVOKE ALL ON FUNCTION issue_exchange_coupon(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION issue_exchange_coupon(uuid, text) FROM anon;
REVOKE ALL ON FUNCTION issue_exchange_coupon(uuid, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION issue_exchange_coupon(uuid, text) TO service_role;

-- Copyright (c) 2026 小塩颯汰
-- Released under the MIT License.
