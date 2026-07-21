-- 原子的な残高加算 / 駐輪場 occupied 減算用の RPC 関数
--
-- 既存の Edge Function は SELECT → 計算 → UPDATE の read-modify-write パターンで、
-- 同時実行時に書き込みが取りこぼれる race condition があった。
-- 単一 SQL の UPDATE で原子的に処理する関数を用意し、Edge Function から RPC で呼ぶ。

-- ============================================================
-- 1. add_points
-- ============================================================
-- ユーザーのポイント残高に delta を加算（負数も可）。下限は 0。
-- 達成発行（+10pt）と将来の調整用途で使う。
-- 戻り値: 加算後の残高

CREATE OR REPLACE FUNCTION add_points(p_user_id uuid, p_delta int)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance int;
BEGIN
  UPDATE points
  SET balance = GREATEST(balance + p_delta, 0)
  WHERE user_id = p_user_id
  RETURNING balance INTO v_balance;

  -- handle_new_user トリガで通常は事前作成されているが、念のため fallback
  IF NOT FOUND THEN
    INSERT INTO points (user_id, balance)
    VALUES (p_user_id, GREATEST(p_delta, 0))
    RETURNING balance INTO v_balance;
  END IF;

  RETURN v_balance;
END;
$$;

GRANT EXECUTE ON FUNCTION add_points(uuid, int) TO service_role, authenticated;

-- ============================================================
-- 2. decrement_parking_occupied
-- ============================================================
-- 駐輪場の occupied を 1 減算（下限 0）。出庫時に呼ぶ。
-- 戻り値: 減算後の occupied

CREATE OR REPLACE FUNCTION decrement_parking_occupied(p_parking_lot_id text)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_occupied int;
BEGIN
  UPDATE parking_lots
  SET occupied = GREATEST(occupied - 1, 0)
  WHERE id = p_parking_lot_id
  RETURNING occupied INTO v_occupied;

  RETURN v_occupied;
END;
$$;

GRANT EXECUTE ON FUNCTION decrement_parking_occupied(text) TO service_role, authenticated;

-- Copyright (c) 2026 小塩颯汰
-- Released under the MIT License.
