# BicycleGo API契約ドキュメント（草案）

アプリ（Flutter）↔ バックエンド間のインターフェース契約。
DB/サーバ側実装の仕様書として使用する。

> 本ドキュメントは現状のモック実装（`MockApiClient`）を正としてまとめたもの。
> 変更は必ずアプリ担当とDB担当の双方合意で行う。

---

## 0. 前提と確認事項

- [x] **バックエンド方式**: **Supabase で確定**。Postgres + Auth + Storage + Edge Functions + Realtime を活用想定。
  - 読み取り系・書き込み系は基本 `supabase_flutter` クライアントから直接（PostgREST 経由）
  - 副作用が大きい処理（`evaluateEarn`、`postParkingDetect`、IoTイベント受信）は Edge Function を推奨
- [ ] **認証**: **Anonymous Sign-In を初期採用**（端末紐付けで匿名利用可）。後にメール/Apple/Google にアップグレード可能。
  - `userId` は `auth.users.id`（uuid）。アプリ側 `currentUserIdProvider` をこの ID に差し替える。
  - 端末側で生成する `deviceId`（[user_providers.dart](../lib/features/user/providers/user_providers.dart) の `deviceIdProvider`）は `users.device_id` に紐付け（機種変更検知用）。
- [ ] **IoT駆動エンドポイント** (`postParkingDetect`): **Edge Function 想定**。service-role キーで認証、IoT 側から HTTP POST。
- [ ] **リアルタイム性**:
  - `parking_lots.occupied` は Realtime 購読推奨（地図のリアルタイム反映）。
  - `parking_sessions` は本人分のみ購読（自分の session 状態変化を即時反映）。
- [x] **日時フォーマット**: **ISO8601 UTC で統一**。クライアント側でローカル時刻に変換。
- [ ] **冪等性**: `redeemCoupon` は同じ couponId に対する 2 度目の呼び出しでエラー（`already_used`）にする想定。要合意。

---

## 1. ドメインモデル（データ型）

### ParkingLot（駐輪場）
| フィールド | 型 | 必須 | 備考 |
|---|---|---|---|
| id | string | ○ | 主キー |
| name | string | ○ | |
| position | `{lat: number, lng: number}` | ○ | |
| capacity | int | ○ | 収容台数 |
| occupied | int | ○ | 現在利用台数 |
| priceYenPerDay | int | ○ | 料金（プロト用） |
| updatedAt | datetime (ISO8601) | ○ | 空き状況の最終更新時刻 |

派生値（サーバ側では持たない、アプリで計算）:
- `available = capacity - occupied`
- `usageRatePercent = round(occupied / capacity * 100)`

### Store（提携店舗）
| フィールド | 型 | 必須 | 備考 |
|---|---|---|---|
| id | string | ○ | 主キー |
| name | string | ○ | |
| category | enum | ○ | `cafe / restaurant / bakery / retail / sweets / bar` |
| position | `{lat: number, lng: number}` | ○ | |
| benefit | string | ○ | 特典表示文字列（例: "ドリンク10%OFF"） |
| recommendWeight | float | ○ | レコメンドの重み（0.0〜1.0） |

### Device（IoT端末）
| フィールド | 型 | 必須 | 備考 |
|---|---|---|---|
| id | string | ○ | |
| storeId | string | ○ | FK → Store |
| parkingLotId | string | ○ | FK → ParkingLot |
| position | `{lat: number, lng: number}` | ○ | 設置位置（GPS照合用） |
| status | enum | ○ | `idle / detecting / awaitingAuth / measuring / completed / offline` |
| nfcCode | string | ○ | NFC読取コード |

### ParkingSession（駐輪セッション）
| フィールド | 型 | 必須 | 備考 |
|---|---|---|---|
| id | string | ○ | |
| deviceId | string | ○ | FK → Device |
| userId | string | ー | 認証前は null |
| detectedAt | datetime | ○ | IoT検知時刻 |
| authenticatedAt | datetime | ー | NFC認証時刻 |
| exitedAt | datetime | ー | 出庫時刻（CheckoutSheet で確定） |
| status | enum | ○ | `unauthenticated / measuring / achieved / parked / completed / expired` |
| issuedCouponId | string | ー | 獲得したクーポンID |

時間ルール（ビジネスロジック）:
- **認証猶予**: `detectedAt` から **5分以内** に認証必須。超過で `expired`。
- **達成しきい値**: `authenticatedAt` から **15分経過** でクーポン発行対象。
- **`parked` 状態**: `achieved` 後にユーザーが「あとで使う（駐輪は継続中）」を選んだ場合に遷移。`endSession` 呼び出しまで継続。サーバ側では `achieved` と同様に扱って良い（クライアント側のUI状態のみで使う）。
- **長時間アラート**: 24時間（現状フロントのみの参照値）。

### ExchangeItem（ポイント交換カタログ） — 新規
| フィールド | 型 | 必須 | 備考 |
|---|---|---|---|
| id | string | ○ | 主キー |
| title | string | ○ | 商品名（例: コーヒー1杯無料券） |
| description | string | ○ | 詳細説明 |
| costPoints | int | ○ | 必要ポイント |
| category | enum | ○ | `coffee / food / retail / mobility / donation` |
| validityDays | int | ○ | 発行クーポンの有効日数（現状30日固定） |

> 現状はクライアント側の固定カタログ（[exchange_catalog_data.dart](../lib/features/points/data/exchange_catalog_data.dart)）で定義。DB化するとカタログ追加・差し替えがアプリ更新無しで可能になる。

### Points（ポイント残高）
| フィールド | 型 | 必須 | 備考 |
|---|---|---|---|
| userId | string | ○ | PK |
| balance | int | ○ | 現在残高 |
| updatedAt | datetime | ○ | |

増減イベントは別テーブル `point_transactions` で記録推奨（監査・不正検知のため）。

### Coupon（クーポン）
| フィールド | 型 | 必須 | 備考 |
|---|---|---|---|
| id | string | ○ | |
| storeId | string | ○ | FK → Store |
| storeName | string | ○ | 非正規化（表示用） |
| title | string | ○ | |
| benefit | string | ○ | |
| issuedAt | datetime | ○ | |
| expiresAt | datetime | ○ | |
| usedAt | datetime | ー | |
| status | enum | ○ | `distributing / owned / used / expired` |
| distanceTier | enum | ○ | `near / far / exchange`（発行時の距離区分） |

---

## 2. エンドポイント契約

現状のアプリは `ApiClient` 抽象クラス（[lib/core/api/api_client.dart](../lib/core/api/api_client.dart)）経由でのみ通信する。
以下の **10メソッド** が呼ばれる。

### 2.1 `postParkingDetect`
- **用途**: IoT→サーバ。駐輪検知通知。
- **入力**: `deviceId`, `detectedAt`
- **出力**: `ParkingSession`（`unauthenticated` 状態で新規作成 or 既存のpending返却）
- **エラー**: `DeviceNotFoundException`

### 2.2 `postParkingAuth`
- **用途**: アプリ→サーバ。NFC認証 + GPS照合。
- **入力**: `userId`, `deviceId`, `lat`, `lng`
- **出力**: `ParkingSession`（`measuring` 状態）
- **エラー**:
  - `GpsMismatchException`: デバイス位置から **80m超** で離れている
  - `AuthGraceExpiredException`: `detectedAt` から5分超過
  - `DeviceNotFoundException`

### 2.3 `evaluateEarn`
- **用途**: 15分経過判定とクーポン発行。
- **入力**: `sessionId`, `userLat`, `userLng`
- **出力**: `Coupon?`（15分未満なら null）
- **副作用**: 発行時、`session.status = achieved`、`session.issuedCouponId` 設定、ユーザーのクーポンリストに追加
- **ロジック**: 近傍店舗をスコア化 `distance / (recommendWeight + 0.01)` で最小選択 → `distanceTier` を距離で決定（<200m=near, <800m=far, それ以外=exchange）

### 2.4 `getUserCoupons`
- **入力**: `userId`
- **出力**: `List<Coupon>`

### 2.5 `redeemCoupon`
- **入力**: `userId`, `couponId`
- **出力**: `Coupon`（`status=used`, `usedAt=now`）
- **エラー**:
  - 見つからない: `ApiException('not_found', ...)`
  - 既に使用済み: `ApiException('already_used', ...)`（**冪等性**: 2回目の呼び出しは必ずエラー）
- **副作用**: `coupons.status = 'used'`、`used_at = now()`

### 2.6 `endSession`
- **入力**: `sessionId`
- **出力**: `ParkingSession`（`status=completed`, `exitedAt=now`）
- **副作用**: 該当 session の駐輪場 `parking_lots.occupied -= 1`（駐輪場の空き反映）。
- **注意**: クライアントは出庫時に [SessionHistory.updateCompletedAt](../lib/features/sessions/providers/session_history_providers.dart) で**履歴の completedAt を実出庫時刻に更新**する。これは端末ローカルのみ（履歴DB化する場合はサーバ側にも同等のフィールドが必要）。

### 2.7 `issueExchangeCoupon`
- **用途**: ポイント交換による即時クーポン発行（駐輪達成と異なり距離スコア無関係）。
- **入力**: `userId`, `exchangeItemId`, `displayStoreName`, `title`, `benefit`, `validity` (Duration)
- **出力**: `Coupon`（`status=owned`、`distanceTier=exchange`、`expiresAt = now + validity`）
- **エラー**:
  - 残高不足: `ApiException('insufficient_points', ...)`
  - カタログ ID 不正: `ApiException('exchange_item_not_found', ...)`
- **副作用**:
  - `coupons` に新規 row 作成（`storeId='exchange-{exchangeItemId}'`）
  - `points.balance -= exchangeItem.costPoints`
  - `point_transactions` に減算履歴記録
- **トランザクション**: 上記3つは**1トランザクションで原子的に**実行（残高だけ減って発行失敗、を防ぐ）

### 2.8 `getParkingLots`
- **出力**: `List<ParkingLot>`
- **Realtime購読推奨**: `parking_lots` テーブルの UPDATE を購読すると地図が自動更新できる。

### 2.9 `getStores`
- **出力**: `List<Store>`
- 配信中フラグや表示期間が必要なら将来 `is_active`, `valid_from/to` を追加。

### 2.10 `getActiveSession`
- **入力**: `userId`
- **出力**: `ParkingSession?`（`measuring` / `achieved` / `parked` 状態のものを返す）

---

## 2.x サンプル JSON（`postParkingAuth`）

### Request
```json
POST /functions/v1/parking_auth
Authorization: Bearer <user-jwt>
{
  "deviceId": "dev-osaka-st-01",
  "lat": 34.7025,
  "lng": 135.4959
}
```

### Response (200)
```json
{
  "id": "ses-1719981234-1",
  "deviceId": "dev-osaka-st-01",
  "userId": "auth-uuid-...",
  "detectedAt": "2026-04-25T05:00:00Z",
  "authenticatedAt": "2026-04-25T05:00:30Z",
  "exitedAt": null,
  "status": "measuring",
  "issuedCouponId": null
}
```

### Error (422 - GPS不一致)
```json
{
  "code": "gps_mismatch",
  "message": "スタンドから約120m離れています。現地で再度お試しください。"
}
```

---

## 3. 例外契約

アプリ側では以下の例外型で分岐している。サーバからは**型を識別できるエラーコード**で返す（HTTPステータス + bodyに `code` フィールド等）。

| 例外型 | 意味 | 返し方の例 |
|---|---|---|
| `DeviceNotFoundException` | device 不在 | 404 `{"code": "device_not_found"}` |
| `SessionNotFoundException` | session 不在 | 404 `{"code": "session_not_found"}` |
| `GpsMismatchException` | GPS照合失敗 | 422 `{"code": "gps_mismatch", "message": "..."}` |
| `AuthGraceExpiredException` | 5分超過 | 422 `{"code": "auth_grace_expired"}` |
| `ApiException` | 汎用 | 4xx/5xx `{"code": "...", "message": "..."}` |

クライアント側の例外マッピングは [api_exceptions.dart](../lib/core/api/api_exceptions.dart) を参照。`code` フィールドで分岐する。

---

## 3.5 RLS（Row Level Security）方針

Supabase 採用にあたり、最低限必要なポリシー想定。

| テーブル | SELECT | INSERT | UPDATE | DELETE |
|---|---|---|---|---|
| `users` | 自分のみ | Auth フック | 自分のみ | 不可 |
| `parking_lots` | 全員 | 不可（管理者のみ） | service-role のみ（IoT/管理） | 不可 |
| `stores` | 全員 | 不可 | 不可 | 不可 |
| `devices` | 不可（クライアント不要） | 不可 | service-role のみ | 不可 |
| `parking_sessions` | 自分の userId のみ | service-role 経由（Edge Function） | 自分のみ（出庫操作） | 不可 |
| `coupons` | 自分の userId のみ | service-role 経由 | 自分のみ（消込時 status 変更） | 不可 |
| `points` | 自分のみ | Auth フック | service-role 経由（不正防止） | 不可 |
| `point_transactions` | 自分のみ | service-role 経由 | 不可（イベントソース） | 不可 |
| `exchange_items` | 全員 | 不可 | 不可 | 不可 |

**Edge Function 経由が必要なもの**: `evaluateEarn`、`postParkingDetect`、`postParkingAuth`、`issueExchangeCoupon`、`redeemCoupon`。残高や発行ロジックを service-role キーで安全に処理。

---

## 4. 参照実装（動作の正）

- **モック実装**: `lib/core/api/mock_api_client.dart`
  - GPS 80m チェック、5分猶予、15分達成、レコメンドのスコア計算はこの挙動を踏襲してほしい。
- **サンプルデータ**: `lib/features/parking/data/parking_mock_data.dart`, `lib/features/stores/data/store_mock_data.dart`
  - 初期シードに流用可。

---

## 5. スキーマ初期案（参考・DB担当判断）

※ あくまで参考。正規化/インデックス/Postgres ENUM 化等は DB 担当の判断に委ねる。

```
users (id [auth.users.id], device_id, nickname?, created_at)
stores (id, name, category, lat, lng, benefit, recommend_weight, created_at)
parking_lots (id, name, lat, lng, capacity, occupied, price_yen_per_day, updated_at)
devices (id, store_id FK, parking_lot_id FK, lat, lng, status, nfc_code)
parking_sessions (id, device_id FK, user_id FK?, detected_at, authenticated_at?, exited_at?, status, issued_coupon_id FK?)
coupons (id, user_id FK, store_id, store_name, title, benefit, issued_at, expires_at, used_at?, status, distance_tier)
exchange_items (id, title, description, cost_points, category, validity_days, is_active)
points (user_id PK FK, balance, updated_at)
point_transactions (id, user_id FK, delta, kind [earn|exchange|adjust], related_session_id?, related_exchange_item_id?, created_at)
```

**インデックス候補（参考）**
- `coupons (user_id, status, expires_at)` — クーポン一覧の絞り込み
- `parking_sessions (user_id, status)` — `getActiveSession`
- `parking_lots` の `position` に PostGIS 入れるなら GiST インデックス（範囲検索想定）

**`distance_tier` の決定（クライアント実装と合わせる）**
- `<200m` → `near`
- `<800m` → `far`
- それ以上 → `exchange`

---

## 6. 統合の進め方（双方合意前提）

1. このドキュメントをレビュー、未確定事項（§0）を埋める
2. サーバ側でスキーマ設計・API実装
3. アプリ側で `SupabaseApiClient implements ApiClient` を実装（DB担当が同じファイルで実装する想定）
4. [api_providers.dart](../lib/core/api/api_providers.dart) の `apiClientProvider` を環境変数で切替可能に
   ```dart
   final apiClientProvider = Provider<ApiClient>((ref) {
     return const bool.fromEnvironment('USE_SUPABASE')
         ? SupabaseApiClient(...)
         : MockApiClient();
   });
   ```
5. **読み取り系** (`getParkingLots` / `getStores`) から段階的に実接続へ切替
6. 書き込み系（認証・クーポン発行）は IoT連携テスト含めて後フェーズで

---

## 7. クライアント側ローカル保存（サーバ移行不要）

以下は端末ローカルに `shared_preferences` で保持しており、**バックエンド実装の対象外**。
将来「機種変更でも引き継ぎたい」となれば各々サーバに上げる検討対象になるが、初期リリースでは対象外で良い。

| データ | 保存キー | 補足 |
|---|---|---|
| お気に入り駐輪場 | `favorite_parking_ids_v1` | UI 表示用のブックマーク |
| 駐輪履歴 | `session_history_v1` | クーポン獲得時に追加・出庫時に completedAt 更新 |
| 交換履歴 | `exchange_history_v1` | UI 表示用。本来は `point_transactions` から派生可能 |
| テーマ設定 | `app_theme_mode_v1` | system / light / dark |
| オンボーディング完了 | `onboarding_completed_v1` | 初回起動判定 |
| ユーザープロファイル | `user_profile_v1` | ニックネーム（後で users テーブルに移行可） |
| デバイスID | `device_id_v1` | 機種変更検知用。`users.device_id` に紐付け予定 |

> 「履歴系」「ポイント取引」をサーバ化する場合、サーバ側集計を正として端末側のキャッシュを更新する設計に切替。

---

## 8. 環境変数

`env/dev.json`（gitignore済）に以下を追加予定：

```json
{
  "GOOGLE_DIRECTIONS_API_KEY": "...",
  "SUPABASE_URL": "https://xxxx.supabase.co",
  "SUPABASE_ANON_KEY": "..."
}
```

`env/dev.example.json` をテンプレとして用意してリポジトリに含める。
