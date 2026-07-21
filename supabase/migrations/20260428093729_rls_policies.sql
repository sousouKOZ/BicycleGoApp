-- BicycleGo Row Level Security ポリシー
--
-- 設計方針: docs/api_contract.md §3.5 / docs/server_implementation.md §6
--
-- 原則:
--   - 書き込み系は基本的に Edge Function 経由（service_role キーで実行）。
--     クライアントから直接 INSERT/UPDATE できる範囲は最小限に絞る。
--   - 読み取りは「自分のデータのみ」と「全員公開」の二択。
--   - DELETE は基本許可しない（履歴保持のため）。

-- ============================================================
-- 1. RLS を全テーブルで有効化
-- ============================================================

ALTER TABLE users               ENABLE ROW LEVEL SECURITY;
ALTER TABLE stores              ENABLE ROW LEVEL SECURITY;
ALTER TABLE parking_lots        ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices             ENABLE ROW LEVEL SECURITY;
ALTER TABLE parking_sessions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE coupons             ENABLE ROW LEVEL SECURITY;
ALTER TABLE exchange_items      ENABLE ROW LEVEL SECURITY;
ALTER TABLE points              ENABLE ROW LEVEL SECURITY;
ALTER TABLE point_transactions  ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. users
-- ============================================================
-- 自分の row のみ SELECT/UPDATE。INSERT は handle_new_user トリガでのみ。

CREATE POLICY users_select_own ON users
  FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY users_update_own ON users
  FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- ============================================================
-- 3. stores（公開マスタ）
-- ============================================================

CREATE POLICY stores_select_all ON stores
  FOR SELECT
  USING (true);

-- 書き込みは service_role のみ（admin operation）。RLS では service_role はバイパスされるためポリシー不要。

-- ============================================================
-- 4. parking_lots（公開マスタ）
-- ============================================================

CREATE POLICY parking_lots_select_all ON parking_lots
  FOR SELECT
  USING (true);

-- 空き状況の更新は Edge Function（service_role）経由。

-- ============================================================
-- 5. devices
-- ============================================================
-- クライアントは device 一覧を取得する必要は無い（NFC タグから ID を直接得る）。
-- 万一参照が必要になっても影響が少ないよう SELECT のみ全員許可しておく。

CREATE POLICY devices_select_all ON devices
  FOR SELECT
  USING (true);

-- ============================================================
-- 6. parking_sessions
-- ============================================================
-- 自分の userId のセッションのみ閲覧可。
-- 出庫操作（status を completed に更新）は自分の row のみ可。
-- 認証・新規作成は Edge Function 経由。

CREATE POLICY sessions_select_own ON parking_sessions
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY sessions_update_own_checkout ON parking_sessions
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- ============================================================
-- 7. coupons
-- ============================================================
-- 自分のクーポンのみ閲覧可。消込は自分の owned → used のみ。
-- 発行は Edge Function 経由。

CREATE POLICY coupons_select_own ON coupons
  FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY coupons_redeem_own ON coupons
  FOR UPDATE
  USING (auth.uid() = user_id AND status = 'owned')
  WITH CHECK (
    auth.uid() = user_id
    AND status IN ('owned', 'used')
  );

-- ============================================================
-- 8. exchange_items（公開カタログ）
-- ============================================================

CREATE POLICY exchange_items_select_active ON exchange_items
  FOR SELECT
  USING (is_active = true);

-- ============================================================
-- 9. points
-- ============================================================
-- 自分の残高のみ閲覧可。書き込みは Edge Function 経由。

CREATE POLICY points_select_own ON points
  FOR SELECT
  USING (auth.uid() = user_id);

-- ============================================================
-- 10. point_transactions
-- ============================================================
-- 自分の取引履歴のみ閲覧可。書き込みは Edge Function 経由。

CREATE POLICY point_transactions_select_own ON point_transactions
  FOR SELECT
  USING (auth.uid() = user_id);

-- Copyright (c) 2026 小塩颯汰
-- Released under the MIT License.
