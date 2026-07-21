-- BicycleGo 初期スキーマ
--
-- 設計方針: docs/server_implementation.md §2 / docs/api_contract.md §5
-- 後続マイグレーションで RLS ポリシー（policies）と関数（functions）を追加する。

-- ============================================================
-- 1. ENUM 型
-- ============================================================

CREATE TYPE coupon_status AS ENUM
  ('distributing', 'owned', 'used', 'expired');

CREATE TYPE coupon_distance_tier AS ENUM
  ('near', 'far', 'exchange');

CREATE TYPE parking_session_status AS ENUM
  ('unauthenticated', 'measuring', 'achieved', 'parked', 'completed', 'expired');

CREATE TYPE store_category AS ENUM
  ('cafe', 'restaurant', 'bakery', 'retail', 'sweets', 'bar');

CREATE TYPE exchange_category AS ENUM
  ('coffee', 'food', 'retail', 'mobility', 'donation');

-- ============================================================
-- 2. ビジネスルール定数（Edge Function 側で定数として持つ）
-- ============================================================
-- 認証猶予 5分、達成しきい値 15分。
-- アプリ側 lib/features/parking/domain/parking_session.dart の値と一致させる。
-- ※ Supabase ローカル環境では ALTER DATABASE SET の権限が無いため、
--   Edge Function 側に const として定義する方針（supabase/functions/_shared/constants.ts）。

-- ============================================================
-- 3. users
-- ============================================================
-- auth.users と 1:1 で紐付く拡張プロファイル。
-- アプリ側 currentUserIdProvider は auth.users.id を直接参照するため、
-- このテーブルの id は auth.users.id を流用する。

CREATE TABLE users (
  id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id   text,
  nickname    text,
  fcm_token   text,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 4. stores（提携店舗）
-- ============================================================

CREATE TABLE stores (
  id                text PRIMARY KEY,
  name              text NOT NULL,
  category          store_category NOT NULL,
  lat               double precision NOT NULL,
  lng               double precision NOT NULL,
  benefit           text NOT NULL,
  recommend_weight  real NOT NULL DEFAULT 0.5,
  created_at        timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 5. parking_lots（駐輪場）
-- ============================================================

CREATE TABLE parking_lots (
  id                  text PRIMARY KEY,
  name                text NOT NULL,
  lat                 double precision NOT NULL,
  lng                 double precision NOT NULL,
  capacity            int NOT NULL,
  occupied            int NOT NULL DEFAULT 0,
  price_yen_per_day   int NOT NULL,
  updated_at          timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT parking_lots_occupied_range CHECK (occupied >= 0 AND occupied <= capacity)
);

-- ============================================================
-- 6. devices（NFC / IoT デバイス = 駐輪スタンド）
-- ============================================================
-- 提携店舗とは紐付けない（システム全体で全店舗を共通の提携先として扱い、
-- 推薦は駐輪場座標と店舗座標の距離・重みで動的に決定する設計）。
-- 「この駐輪場では特定の店舗だけ」という要件が出たら parking_lot_stores の
-- 中間テーブルを後付けする。

CREATE TABLE devices (
  id              text PRIMARY KEY,
  parking_lot_id  text NOT NULL REFERENCES parking_lots(id) ON DELETE CASCADE,
  lat             double precision NOT NULL,
  lng             double precision NOT NULL,
  status          text NOT NULL DEFAULT 'idle',
  nfc_code        text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_devices_parking_lot ON devices (parking_lot_id);

-- ============================================================
-- 7. parking_sessions（駐輪セッション）
-- ============================================================

CREATE TABLE parking_sessions (
  id                 text PRIMARY KEY,
  device_id          text NOT NULL REFERENCES devices(id) ON DELETE RESTRICT,
  user_id            uuid REFERENCES users(id) ON DELETE SET NULL,
  detected_at        timestamptz NOT NULL,
  authenticated_at   timestamptz,
  exited_at          timestamptz,
  status             parking_session_status NOT NULL,
  issued_coupon_id   text,                                     -- coupons FK は循環するため後段で
  created_at         timestamptz NOT NULL DEFAULT now()
);

-- アクティブセッション検索（getActiveSession）
CREATE INDEX idx_sessions_user_status
  ON parking_sessions (user_id, status)
  WHERE status IN ('measuring', 'achieved', 'parked');

-- pg_cron が達成判定でスキャンする partial index
CREATE INDEX idx_sessions_pending_earn
  ON parking_sessions (authenticated_at)
  WHERE status = 'measuring';

-- 5分超過の expired 化に使う partial index
CREATE INDEX idx_sessions_pending_auth
  ON parking_sessions (detected_at)
  WHERE status = 'unauthenticated';

-- ============================================================
-- 8. coupons
-- ============================================================
-- store_id は提携店舗の場合 stores(id) を参照、ポイント交換クーポンの場合
-- 'exchange-{exchange_item_id}' 形式の文字列を入れる（FK にしない）。

CREATE TABLE coupons (
  id              text PRIMARY KEY,
  user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  store_id        text NOT NULL,
  store_name      text NOT NULL,
  title           text NOT NULL,
  benefit         text NOT NULL,
  issued_at       timestamptz NOT NULL DEFAULT now(),
  expires_at      timestamptz NOT NULL,
  used_at         timestamptz,
  status          coupon_status NOT NULL DEFAULT 'owned',
  distance_tier   coupon_distance_tier NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- クーポン一覧の絞り込み（user_id × status × expires_at）
CREATE INDEX idx_coupons_user_status_expires
  ON coupons (user_id, status, expires_at);

-- parking_sessions.issued_coupon_id への FK は後付け（循環参照のため）
ALTER TABLE parking_sessions
  ADD CONSTRAINT parking_sessions_issued_coupon_fk
  FOREIGN KEY (issued_coupon_id) REFERENCES coupons(id) ON DELETE SET NULL;

-- ============================================================
-- 9. exchange_items（ポイント交換カタログ）
-- ============================================================

CREATE TABLE exchange_items (
  id              text PRIMARY KEY,
  title           text NOT NULL,
  description     text NOT NULL,
  cost_points     int NOT NULL CHECK (cost_points > 0),
  category        exchange_category NOT NULL,
  validity_days   int NOT NULL DEFAULT 30 CHECK (validity_days > 0),
  is_active       boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- ============================================================
-- 10. points（残高） / point_transactions（取引履歴）
-- ============================================================

CREATE TABLE points (
  user_id     uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  balance     int NOT NULL DEFAULT 0 CHECK (balance >= 0),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TYPE point_transaction_kind AS ENUM ('earn', 'exchange', 'adjust');

CREATE TABLE point_transactions (
  id                          bigserial PRIMARY KEY,
  user_id                     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  delta                       int NOT NULL,
  kind                        point_transaction_kind NOT NULL,
  related_session_id          text REFERENCES parking_sessions(id) ON DELETE SET NULL,
  related_exchange_item_id    text REFERENCES exchange_items(id) ON DELETE SET NULL,
  note                        text,
  created_at                  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_point_transactions_user_created
  ON point_transactions (user_id, created_at DESC);

-- ============================================================
-- 11. updated_at 自動更新トリガ
-- ============================================================

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_set_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER parking_lots_set_updated_at
  BEFORE UPDATE ON parking_lots
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER points_set_updated_at
  BEFORE UPDATE ON points
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ============================================================
-- 12. auth.users 作成時に public.users と points を自動生成
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user() RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id) VALUES (NEW.id) ON CONFLICT DO NOTHING;
  INSERT INTO public.points (user_id, balance) VALUES (NEW.id, 0) ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 13. Realtime 有効化
-- ============================================================
-- 地図の駐輪場空き状況・自分のセッション状態をリアルタイム購読するため。

ALTER PUBLICATION supabase_realtime ADD TABLE parking_lots;
ALTER PUBLICATION supabase_realtime ADD TABLE parking_sessions;

-- Copyright (c) 2026 小塩颯汰
-- Released under the MIT License.
