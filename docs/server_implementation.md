# BicycleGo サーバ実装ガイド（Supabase）

サーバ側で実装する処理の仕様書。DB / バックエンド担当者向け。
**API インタフェース仕様（リクエスト・レスポンス・例外）は [api_contract.md](api_contract.md) を参照**。本ドキュメントはそこに書かれていない「サーバ自律で動く処理」と「Supabase 上での具体的な実装ポイント」をまとめる。

---

## 0. このドキュメントの読み方

- API シグネチャ・ドメインモデル・スキーマ初期案 → [api_contract.md](api_contract.md)
- **本書**：Edge Function / pg_cron / プッシュ通知 / Realtime / 推薦ロジック / RLS の実装方針

両方を読んで、両者で認識合わせした上で実装着手してください。

---

## 1. 全体構成

```
┌──────────────────────┐
│ Flutter アプリ       │
│  - supabase_flutter  │
│  - firebase_messaging│
└─────┬────────┬───────┘
      │        │
      │ REST   │ FCM/APNs
      │ +      │ push
      │ Realtime
      ▼        ▲
┌──────────────────────┐
│ Supabase             │
│  ┌────────────────┐  │
│  │ Postgres       │  │ ← データ実体
│  │  + RLS         │  │
│  │  + pg_cron     │  │ ← 15分達成判定スケジューラ
│  └────────────────┘  │
│  ┌────────────────┐  │
│  │ Edge Functions │  │ ← 認証・発行・消込・push
│  └────────────────┘  │
│  ┌────────────────┐  │
│  │ Realtime       │  │ ← 駐輪場空き状況の即時反映
│  └────────────────┘  │
└──────────────────────┘
      ▲
      │ HTTPS（service-role）
      │
┌──────────────────────┐
│ IoT デバイス         │ ← 駐輪検知 → サーバへ
│ （将来導入）         │
└──────────────────────┘
```

---

## 2. データベース構築

スキーマ初期案は [api_contract.md §5](api_contract.md) を参照。本書での補足：

### 2.1 ENUM 化推奨

```sql
CREATE TYPE coupon_status AS ENUM
  ('distributing', 'owned', 'used', 'expired');

CREATE TYPE coupon_distance_tier AS ENUM ('near', 'far', 'exchange');

CREATE TYPE parking_session_status AS ENUM
  ('unauthenticated', 'measuring', 'achieved',
   'parked', 'completed', 'expired');

CREATE TYPE store_category AS ENUM
  ('cafe', 'restaurant', 'bakery', 'retail', 'sweets', 'bar');

CREATE TYPE exchange_category AS ENUM
  ('coffee', 'food', 'retail', 'mobility', 'donation');
```

### 2.2 ビジネスルールを DB で持つ定数

```sql
-- 認証猶予 5分、達成しきい値 15分
ALTER DATABASE postgres SET app.auth_grace_seconds = 300;
ALTER DATABASE postgres SET app.earn_threshold_seconds = 900;
```

`current_setting('app.earn_threshold_seconds')::int` で参照可能。アプリ側の `parking_session.dart` の値と一致させる。

### 2.3 検索性能のためのインデックス

```sql
-- クーポン一覧の絞り込み
CREATE INDEX idx_coupons_user_status ON coupons (user_id, status, expires_at);

-- アクティブセッション検索
CREATE INDEX idx_sessions_user_status ON parking_sessions (user_id, status)
  WHERE status IN ('measuring', 'achieved', 'parked');

-- 達成判定スケジューラ用
CREATE INDEX idx_sessions_pending_earn ON parking_sessions (authenticated_at)
  WHERE status = 'measuring';
```

最後の partial index が **§4.3 の cron 処理を高速化する鍵**。

---

## 3. 認証（Supabase Auth）

### 3.1 採用方式

**Anonymous Sign-In** を初期採用。`supabase.auth.signInAnonymously()` で `auth.users.id` (uuid) を発行。

将来的にメール／Apple／Google にアップグレード可能（同じ `auth.users` row のまま）。

### 3.2 アプリ起動時のフロー

```
1. アプリ起動
2. Supabase クライアント初期化
3. supabase.auth.currentUser を確認
4. 未サインインなら signInAnonymously() で uuid 発行
5. アプリ側 deviceIdProvider の値を users.device_id にUPSERT
```

`auth.users` と独立した `public.users` テーブルを置く方針推奨：

```sql
CREATE TABLE users (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  device_id text,
  nickname text,
  created_at timestamptz DEFAULT now()
);

-- auth.users 作成と同期
CREATE FUNCTION public.handle_new_user() RETURNS trigger AS $$
BEGIN
  INSERT INTO public.users (id) VALUES (NEW.id);
  INSERT INTO public.points (user_id, balance) VALUES (NEW.id, 0);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### 3.3 アカウント連携（将来）

匿名ユーザーがメール認証等にアップグレードしても、`auth.users.id` は変わらない仕様（Supabase Auth 標準）。データ移行不要。

---

## 4. Edge Functions

各エンドポイントは Edge Function として実装する。**書き込み系・副作用が大きいものはほぼ全てここ**。

| Function | トリガ | 副作用 |
|---|---|---|
| 4.1 `parking_detect` | IoT デバイス | session 作成（unauthenticated） |
| 4.2 `parking_auth` | アプリ（NFC スキャン後） | session を measuring に遷移 |
| 4.3 `issue_coupons` | **pg_cron 60秒ごと** | 達成 session にクーポン発行 + push 送信 |
| 4.4 `redeem_coupon` | アプリ（スワイプ消込） | クーポン used 化 |
| 4.5 `issue_exchange_coupon` | アプリ（ポイント交換） | クーポン即時発行 + ポイント減算（トランザクション） |
| 4.6 `end_session` | アプリ（出庫） | session completed + 駐輪場 occupied 減算 |
| 4.7 `expire_sessions` | **pg_cron 60秒ごと** | 5分超過した unauthenticated を expired 化 |

### 4.1 `parking_detect`

- **呼び出し元**：IoT デバイス（service-role キーで認証）
- **入力**：`{ deviceId, detectedAt }`
- **処理**：
  1. `devices` で deviceId を検証（無ければ 404）
  2. 同 deviceId に既存の `unauthenticated` session が無ければ新規作成
  3. session を返す

### 4.2 `parking_auth`

- **呼び出し元**：アプリ（ユーザー JWT で認証）
- **入力**：`{ deviceId }`（GPS 廃止済み — 詳細は [api_contract.md §0](api_contract.md) 冪等性ノート参照）
- **処理**：
  1. JWT から `userId` を解決
  2. 該当 deviceId で 5分以内の `unauthenticated` session を検索
  3. 無ければ `auth_grace_expired` エラー
  4. ある場合 `userId` を紐付け、`status='measuring'`、`authenticated_at=now()` で更新
  5. **本番強化案**：将来 NTAG 424 DNA を導入する場合は、ここで MAC 検証を追加（[NFC認証の設計検討](#13-nfc認証の設計検討) 参照）

### 4.3 `issue_coupons` ★ 最重要

**この処理が現状アプリ側で動いている `_checkSession` ポーリングの代替**。サーバ自律で15分達成を検知し、クーポンを発行する。

- **呼び出し元**：pg_cron（60秒ごと、§5 参照）
- **処理**：
  1. `parking_sessions` から条件 `status='measuring' AND authenticated_at + interval '15 minutes' <= now()` で抽出
  2. 各 session について：
     a. 駐輪場（device.parking_lot_id）の座標を取得
     b. **§9 の推薦ロジック**で店舗を1つ選定
     c. クーポンを `coupons` テーブルに INSERT（`status='owned'`, `expires_at=now()+3day`）
     d. session を更新：`status='achieved'`, `issued_coupon_id=新クーポンID`
     e. `point_transactions` に 10pt 加算 + `points.balance` を 10pt 増加（**1トランザクション内で**）
     f. **プッシュ通知を送信**（§7 参照）
  3. 全件 commit

```sql
-- 抽出 SQL の例
SELECT s.id, s.user_id, d.parking_lot_id, p.lat, p.lng
FROM parking_sessions s
JOIN devices d ON s.device_id = d.id
JOIN parking_lots p ON d.parking_lot_id = p.id
WHERE s.status = 'measuring'
  AND s.authenticated_at + interval '15 minutes' <= now()
LIMIT 100;
```

### 4.4 `redeem_coupon`

- **入力**：`{ couponId }`（userId は JWT から）
- **処理**：
  1. `coupons` で id 一致 + user_id == JWT.sub を検証
  2. `status='owned'` でなければ：
     - `used` → `already_used` エラー（**冪等性**：[api_contract.md §0](api_contract.md)）
     - `expired` → `expired` エラー
  3. UPDATE `status='used'`, `used_at=now()`
  4. 更新後 row を返す

### 4.5 `issue_exchange_coupon` ★トランザクション必須

- **入力**：`{ exchangeItemId }`（userId は JWT から）
- **処理（**1トランザクション内で**）**：
  1. `exchange_items` から item を取得（is_active=true 確認）
  2. `points.balance` をロック取得（`SELECT ... FOR UPDATE`）
  3. balance < cost なら `insufficient_points` エラー
  4. `coupons` に新規 INSERT（`status='owned'`, `distance_tier='exchange'`, `expires_at=now()+30day`, `store_id='exchange-{itemId}'`, `store_name='ポイント交換特典'`, `title=item.description`, `benefit=item.title`）
  5. `points.balance -= cost`
  6. `point_transactions` に減算履歴
  7. 新クーポンを返す

### 4.6 `end_session`

- **入力**：`{ sessionId }`
- **処理**：
  1. session を取得（user_id == JWT.sub 確認）
  2. UPDATE `status='completed'`, `exited_at=now()`
  3. **`parking_lots.occupied -= 1`**（駐輪場の空き反映）
  4. Realtime 購読者に通知される（§8）

### 4.7 `expire_sessions`

- **呼び出し元**：pg_cron（60秒ごと）
- **処理**：5分超過 + `unauthenticated` の session を `expired` に更新

```sql
UPDATE parking_sessions
SET status = 'expired'
WHERE status = 'unauthenticated'
  AND detected_at + interval '5 minutes' < now();
```

---

## 5. スケジュールジョブ（pg_cron）

Supabase は pg_cron 拡張機能を有効化できる。Database → Extensions で有効化。

```sql
-- 60秒ごとに15分達成判定 + クーポン発行
SELECT cron.schedule(
  'issue_coupons',
  '* * * * *',
  $$ SELECT net.http_post(
    url := 'https://<project>.supabase.co/functions/v1/issue_coupons',
    headers := jsonb_build_object('Authorization', 'Bearer ' || current_setting('app.service_role_key'))
  ) $$
);

-- 60秒ごとに認証猶予超過 session を expired 化
SELECT cron.schedule(
  'expire_sessions',
  '* * * * *',
  $$ SELECT net.http_post(
    url := 'https://<project>.supabase.co/functions/v1/expire_sessions',
    ...
  ) $$
);
```

または DB 内で完結させたい場合は Edge Function を経由せず PL/pgSQL 関数を直接 cron で呼ぶ設計でも可。**push 通知が必要なため Edge Function 経由を推奨**。

> **検討事項**：60秒間隔だと最大60秒の遅延が出る。ユーザー体験的には許容範囲だが、よりシビアにするなら 10秒間隔に短縮可能（負荷次第）。

---

## 6. Row Level Security

詳細マトリクスは [api_contract.md §3.5](api_contract.md) 参照。本書は実装上の注意点のみ：

```sql
-- ユーザーは自分のクーポンしか SELECT できない
CREATE POLICY "users_read_own_coupons" ON coupons
  FOR SELECT USING (auth.uid() = user_id);

-- 消込は自分のクーポンの status のみ owned → used に変更可能
CREATE POLICY "users_redeem_own_coupon" ON coupons
  FOR UPDATE USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND status = 'used'
    AND OLD.status = 'owned'
  );

-- coupons の INSERT は service-role のみ（Edge Function 経由）
-- DELETE は禁止（履歴保持）
```

`points` も同様に：SELECT は自分のみ、UPDATE/INSERT は service-role のみ。

`parking_lots` と `stores` は全員読み取り可（地図表示のため）。書き込みは service-role のみ。

---

## 7. プッシュ通知（FCM / APNs）

**既存のローカル通知（`flutter_local_notifications`）はサーバ自律発行に置き換わるため不要になる**。

### 7.1 アプリ側の準備

`firebase_messaging` を導入し、`onMessage` / `onBackgroundMessage` ハンドラを追加。
device token を `users.fcm_token` カラムに保存（要追加）。

```sql
ALTER TABLE users ADD COLUMN fcm_token text;
```

### 7.2 サーバ側

`issue_coupons` の最後で：

1. ユーザーの fcm_token を取得
2. FCM Admin SDK 経由で送信（Edge Function は Deno 環境なので Deno 互換のFCM クライアント or HTTP 直叩き）
3. payload 例：

```json
{
  "to": "<fcm_token>",
  "notification": {
    "title": "🎉 クーポンが発行されました！",
    "body": "○○ で使える特典が届きました"
  },
  "data": {
    "type": "coupon_issued",
    "coupon_id": "cp-xxx",
    "session_id": "ses-xxx"
  }
}
```

### 7.3 タップ起動時の動線

アプリ側でペイロードを解析：
- `type=coupon_issued` なら `couponId` から CouponDetailPage へ直接遷移
- そうでなければ通常起動

---

## 8. Realtime 購読

Supabase Realtime で以下を購読推奨：

| テーブル | フィルタ | 用途 |
|---|---|---|
| `parking_lots` | なし | 地図上の空き状況をリアルタイム反映 |
| `parking_sessions` | `user_id=自分` | 自分のセッション状態変化（measuring → achieved 等） |

設定：

```sql
-- Realtime を有効化
ALTER PUBLICATION supabase_realtime ADD TABLE parking_lots;
ALTER PUBLICATION supabase_realtime ADD TABLE parking_sessions;
```

アプリ側は `supabase.channel('parking_lots').on('postgres_changes', ...)` で受信。

---

## 9. 推薦ロジック（クーポン発行時の店舗選定）

[mock_api_client.dart](../lib/core/api/mock_api_client.dart) の `_pickStoreWeighted` を踏襲：

```
入力: parking_lot.lat, parking_lot.lng
出力: 1店舗

各店舗 s について:
  km = haversine(parking_lot.position, s.position) / 1000
  distanceFactor = 1 / (1 + km)        # 1km で半分
  weight = distanceFactor * (s.recommend_weight + 0.05)

合計重み sum = Σ weight
random_value = rand() * sum
累積で random_value を超えた店舗を選択
```

PL/pgSQL での実装例：

```sql
CREATE FUNCTION pick_store_for_parking(p_parking_id text)
RETURNS uuid AS $$
DECLARE
  -- 重み付きランダム選択
BEGIN
  -- ... haversine 計算 + ランダム選択 ...
END;
$$ LANGUAGE plpgsql;
```

距離 tier 判定：

```
distance < 200m  → 'near'
distance < 800m  → 'far'
それ以上         → 'exchange'
```

---

## 10. 環境変数

Supabase プロジェクト → Settings → Edge Functions に登録：

| 変数 | 用途 |
|---|---|
| `SUPABASE_URL` | プロジェクト URL（自動設定） |
| `SUPABASE_SERVICE_ROLE_KEY` | RLS バイパス用（自動設定） |
| `FCM_SERVER_KEY` | FCM 送信用 |

アプリ側は [api_contract.md §8](api_contract.md) の通り `env/dev.json` に Anon Key のみ。

---

## 11. 実装フェーズ

優先順位順：

### Phase 1：読み取り系（半日）
- スキーマ作成 + シードデータ投入（モック値を流用、[parking_mock_data.dart](../lib/features/parking/data/parking_mock_data.dart) / [store_mock_data.dart](../lib/features/stores/data/store_mock_data.dart) 参照）
- RLS 設定（読み取り用ポリシー）
- アプリ側で `getParkingLots` / `getStores` を実接続に切替
- 動作確認

### Phase 2：認証 + セッション
- Anonymous Sign-In 連携
- `parking_detect` / `parking_auth` の Edge Function 実装
- アプリ側で NFC フローを実接続に切替

### Phase 3：自律発行
- pg_cron 設定
- `issue_coupons` Edge Function（推薦ロジック含む）
- `expire_sessions` Edge Function
- アプリ側 `home_shell._checkSession` のポーリングを廃止

### Phase 4：プッシュ通知
- FCM 設定
- アプリ側 `firebase_messaging` 導入
- payload ハンドラ実装
- ローカル通知（`flutter_local_notifications`）の予約処理を廃止

### Phase 5：周辺
- `redeem_coupon` / `issue_exchange_coupon` / `end_session`
- ポイント関連
- Realtime 購読

---

## 12. 開発・テスト環境

### 12.1 ローカル Supabase

```bash
brew install supabase/tap/supabase
supabase init
supabase start  # ローカルで Postgres + Auth + Edge Functions が起動
```

`supabase/migrations/` にマイグレーションを置けば版管理可能。

### 12.2 テストデータ

[parking_mock_data.dart](../lib/features/parking/data/parking_mock_data.dart) と [store_mock_data.dart](../lib/features/stores/data/store_mock_data.dart) のデータをそのまま seed として流用可能。

### 12.3 アプリ側の切替

[api_providers.dart](../lib/core/api/api_providers.dart) の `apiClientProvider` を環境変数で切替：

```dart
final apiClientProvider = Provider<ApiClient>((ref) {
  return const bool.fromEnvironment('USE_SUPABASE')
      ? SupabaseApiClient(...)
      : MockApiClient();
});
```

`flutter run --dart-define=USE_SUPABASE=true` でサーバ接続版に切替。

---

## 13. NFC認証の設計検討

現状はスタンドに紐付けた deviceId（NFC タグ ID）の一致のみで認証。GPS 照合は廃止済み（屋内で誤判定する問題対応）。

### 不正対策の段階導入

| フェーズ | 認証ロジック | コスト |
|---|---|---|
| **Phase 2 完了時** | IoT 検知イベント + NFC UID 一致 + 5分以内 | 低（既存仕様） |
| **本番投入時** | 上記 + NTAG 424 DNA 署名検証 | タグ ¥80〜150/個 |
| **継続的** | サーバ側で異常検知（同IPから複数 deviceId 等） | 監視ダッシュボード |

NTAG 424 DNA は1スキャンごとに署名が変わるため、タグ UID をクローンしても再生攻撃が成立しない。Edge Function で MAC 検証を実装する。

---

## 14. ドキュメント更新責任

- 本書とアプリ側コードに齟齬が出た場合、まず本書を更新
- API 契約変更は [api_contract.md](api_contract.md) を更新（双方合意必要）
- 実装が固まったら本書から「想定」「予定」を削除し、確定仕様化

---

## 付録：用語

| 用語 | 意味 |
|---|---|
| 駐輪セッション | 1回の駐輪行動。検知 → 認証 → 計測 → 達成 → 出庫 のライフサイクル |
| 達成 | 15分経過してクーポン発行対象になった状態 |
| 出庫 | ユーザーが自転車を出した時点。駐輪場の occupied 減算トリガ |
| デバイス | 駐輪スタンド1台 = 1デバイス。NFC タグ + IoT センサが付く想定 |
| 配信中クーポン | ユーザーが取得していない状態のクーポン候補（地図に表示） |
| 利用可能クーポン | 取得済みで未使用・期限内のクーポン |
