# クーポン利用とレコメンド即時同期のアーキテクチャ改善

## Goal Description
アプリ上でユーザーがクーポンを利用（スワイプして消込）した際、その利用履歴が即座にレコメンドアルゴリズムに反映され、画面上の「おすすめ店舗一覧」が更新されるようにする。
同時に、この同期処理によってクーポンのスワイプ処理自体が遅延し、ユーザー体験を損ねることがないよう高速なレスポンスを担保する。

## Background & Problems (Current Behavior)
現在の実装を確認したところ、以下の状態になっています。

1. **Python API側 (`data_store.py`) は起動時に一度だけデータを読み込む仕様**
   現在、Pythonサーバーは起動時にDBからデータを読み込み、メモリ上に巨大な行列（`user_item_matrix` や `user_sim_df` 等）を展開しています。しかし、稼働中にこのデータを更新する仕組みが存在しないため、クーポンを利用してもPythonサーバーを再起動するまでレコメンド結果が変わりません。
2. **Edge Function (`redeem_coupon/index.ts`) はDB更新のみ**
   クーポン利用APIはDBの `coupons` テーブルの `status` を `used` に変えるだけで、Pythonサーバーへ利用実績を通知していません。
3. **Flutter アプリ側でのキャッシュ保持**
   クーポンを使用した後も、`recommendedStoresProvider` のキャッシュが破棄されないため、仮にサーバー側のデータが変わったとしても、ユーザーが手動で画面を更新しない限り古い一覧が表示され続けます。

## Proposed Changes

### 1. Python Recommendation API
全データの再計算や類似度マトリクス（Cosine Similarity）の再計算を回避し、対象店舗の個人的な訪問回数のみをメモリ上で直接インクリメントする超高速（O(1)）エンドポイントを新設します。

#### [MODIFY] `data_store.py`
- `increment_visit(user_id, venue_id, category_name)` メソッドを追加。
- `self.user_item_matrix` および `self.user_cat_matrix` の該当箇所を直接 `+= 1` します。
- `user_id` や `venue_id` がDataFrameのインデックス/カラムに存在しない場合は、新規行・列として追加（0埋め）したうえでインクリメントします。
- > [!TIP]
  > **意図的な非同期**: 類似度マトリクス（`user_sim_df` や `cat_sim_df`）は再計算すると重いため、この軽量APIでは更新しません。個人の訪問履歴スコア（リピート補正等）に即時反映させるだけで十分なUX向上が得られます。

#### [MODIFY] `recommendation_api.py`
- `POST /api/v2/increment_visit` エンドポイントの追加（`@require_internal_api_key` による認証）。
- リクエストボディ: `{"user_id": str, "venue_id": str, "category_name": str}`。

---

### 2. Supabase Edge Functions
クーポンの消込処理時、Pythonサーバーの軽量なインクリメントAPIを呼び出して利用実績を通知します。

#### [MODIFY] `supabase/functions/redeem_coupon/index.ts`
- 現在のクーポン取得クエリで、店舗情報（`store_id` と `stores(category)`）も同時に `select` するように修正します。
- クーポンの `status` を `used` に更新した直後、非同期または `await` で Pythonサーバーの `/api/v2/increment_visit` を呼び出します。
- API呼び出しには `PYTHON_API_KEY` 環境変数を使用します。

---

### 3. Flutter App
クーポン利用完了直後にレコメンド状態のキャッシュを確実に破棄し、新しいデータを再取得させます。

#### [MODIFY] `lib/features/coupons/presentation/coupon_detail_page.dart`
- （および必要に応じて `coupon_list_page.dart` や他画面）
- クーポン消込処理（`ref.read(apiClientProvider).redeemCoupon(...)`）が成功した直後に、`ref.invalidate(recommendedStoresProvider)` を実行します。
- これにより、スワイプ画面から地図やレコメンドタブに戻った際、即座に更新されたレコメンド結果が再取得・描画されます。

## Verification Plan

### Automated Tests
- 今回は主にUXとバックエンド間の連携であるため、手動テストを重視します。

### Manual Verification
1. `python recommendation_api.py` でPythonサーバーを起動。
2. アプリ上で任意のクーポンを利用（スワイプ）する。
3. スワイプアニメーションが遅延なく一瞬で完了することを確認する。
4. 該当するクーポンの店舗が、レコメンドリスト内で「リピートおすすめ」などに昇格し、順位やスコアが変動していることを確認する。
5. （存在しない新規ユーザーや新規店舗の場合でもエラーでクラッシュしないか確認する）
