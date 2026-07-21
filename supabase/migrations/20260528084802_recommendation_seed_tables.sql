-- Python レコメンドAPI用のシードデータテーブル
-- load_data.py によって外部CSVのデータがロードされる。

CREATE TABLE seed_stores (
  id                text PRIMARY KEY,
  name              text NOT NULL,
  category          text,
  lat               double precision NOT NULL,
  lng               double precision NOT NULL,
  budget            int,
  atmosphere        int,
  taste             int,
  cost_performance  int,
  service           int,
  access            int
);

CREATE TABLE seed_checkins (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           bigint NOT NULL,
  venue_id          text NOT NULL REFERENCES seed_stores(id) ON DELETE CASCADE,
  category_name     text,
  checked_in_at     timestamptz NOT NULL,
  time_offset       int
);

CREATE TABLE category_affinity (
  category_a        text NOT NULL,
  category_b        text NOT NULL,
  score             double precision NOT NULL,
  updated_at        timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (category_a, category_b)
);

-- Copyright (c) 2026 小塩颯汰
-- Released under the MIT License.
