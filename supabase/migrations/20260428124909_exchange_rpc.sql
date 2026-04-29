-- ポイント交換クーポン発行を原子的に行う RPC 関数
--
-- 残高チェック・クーポン発行・残高減算・取引履歴登録を
-- 1トランザクションで実行する。途中失敗時は全部ロールバック。

CREATE OR REPLACE FUNCTION issue_exchange_coupon(
  p_user_id          uuid,
  p_exchange_item_id text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item        exchange_items%ROWTYPE;
  v_balance     int;
  v_coupon_id   text;
  v_now         timestamptz := now();
  v_expires_at  timestamptz;
  v_coupon      coupons%ROWTYPE;
BEGIN
  -- 1. 交換カタログ取得（active=true のみ）
  SELECT * INTO v_item
  FROM exchange_items
  WHERE id = p_exchange_item_id AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'exchange_item_not_found' USING ERRCODE = 'P0001';
  END IF;

  -- 2. 残高をロック取得（同時交換による二重消費を防ぐ）
  SELECT balance INTO v_balance
  FROM points
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    -- 通常 handle_new_user トリガで作成されるが、念のため
    INSERT INTO points (user_id, balance) VALUES (p_user_id, 0);
    v_balance := 0;
  END IF;

  IF v_balance < v_item.cost_points THEN
    RAISE EXCEPTION 'insufficient_points' USING ERRCODE = 'P0002';
  END IF;

  -- 3. クーポン作成（distance_tier='exchange'、storeId は仮想 ID）
  v_coupon_id := 'cp-exch-' || extract(epoch from v_now)::bigint || '-' || substr(gen_random_uuid()::text, 1, 8);
  v_expires_at := v_now + (v_item.validity_days || ' days')::interval;

  INSERT INTO coupons (
    id, user_id, store_id, store_name, title, benefit,
    issued_at, expires_at, status, distance_tier
  ) VALUES (
    v_coupon_id,
    p_user_id,
    'exchange-' || v_item.id,
    'ポイント交換特典',
    v_item.description,
    v_item.title,
    v_now,
    v_expires_at,
    'owned',
    'exchange'
  ) RETURNING * INTO v_coupon;

  -- 4. 残高減算
  UPDATE points
  SET balance = balance - v_item.cost_points
  WHERE user_id = p_user_id;

  -- 5. 取引履歴
  INSERT INTO point_transactions (
    user_id, delta, kind, related_exchange_item_id, note
  ) VALUES (
    p_user_id,
    -v_item.cost_points,
    'exchange',
    v_item.id,
    'ポイント交換: ' || v_item.title
  );

  -- 6. 作成したクーポンを JSON で返す
  RETURN to_jsonb(v_coupon);
END;
$$;

-- service_role と authenticated ユーザーから呼び出せるように権限付与
GRANT EXECUTE ON FUNCTION issue_exchange_coupon(uuid, text) TO service_role, authenticated;
