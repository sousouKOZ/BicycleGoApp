# BicycleGo API契約ドキュメント（草案）

アプリ（Flutter）↔ バックエンド間のインターフェース契約。
DB/サーバ側実装の仕様書として使用する。

> 本ドキュメントは現状のモック実装（`MockApiClient`）を正としてまとめたもの。
> 変更は必ずアプリ担当とDB担当の双方合意で行う。

---

## 0. 前提と確認事項（未確定）

- [ ] **バックエンド方式**: Supabase想定だが未確定。REST / Supabaseクライアント直叩き / Flask+PostgreSQL のどれか。
- [ ] **認証**: Supabase Auth? それとも独自? `userId` の発行方法。
- [ ] **IoT駆動エンドポイント** (`POST /api/parking/detect`) の受け口: Edge Function? 別サーバ?
- [ ] **リアルタイム性**: 駐輪場の空き状況は pull（定期GET）か push（Realtime購読）か。
- [ ] **日時フォーマット**: ISO8601 UTC で統一する前提でよいか。

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
| exitedAt | datetime | ー | 出庫時刻 |
| status | enum | ○ | `unauthenticated / measuring / achieved / completed / expired` |
| issuedCouponId | string | ー | 獲得したクーポンID |

時間ルール（ビジネスロジック）:
- **認証猶予**: `detectedAt` から **5分以内** に認証必須。超過で `expired`。
- **達成しきい値**: `authenticatedAt` から **15分経過** でクーポン発行対象。
- **長時間アラート**: 24時間（現状フロントのみの参照値）。

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

現状のアプリは `ApiClient` 抽象クラス（`lib/core/api/api_client.dart`）経由でのみ通信する。
以下の9メソッドが呼ばれる。

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
- **エラー**: 見つからない場合 `ApiException('not_found', ...)`

### 2.6 `endSession`
- **入力**: `sessionId`
- **出力**: `ParkingSession`（`status=completed`, `exitedAt=now`）

### 2.7 `getParkingLots`
- **出力**: `List<ParkingLot>`

### 2.8 `getStores`
- **出力**: `List<Store>`

### 2.9 `getActiveSession`
- **入力**: `userId`
- **出力**: `ParkingSession?`（`measuring` or `achieved` 状態のものを返す）

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

---

## 4. 参照実装（動作の正）

- **モック実装**: `lib/core/api/mock_api_client.dart`
  - GPS 80m チェック、5分猶予、15分達成、レコメンドのスコア計算はこの挙動を踏襲してほしい。
- **サンプルデータ**: `lib/features/parking/data/parking_mock_data.dart`, `lib/features/stores/data/store_mock_data.dart`
  - 初期シードに流用可。

---

## 5. スキーマ初期案（参考・DB担当判断）

※ あくまで参考。正規化/インデックス等はDB担当の判断に委ねる。

```
users (id, name, created_at, ...)
stores (id, name, category, lat, lng, benefit, recommend_weight)
parking_lots (id, name, lat, lng, capacity, occupied, price_yen_per_day, updated_at)
devices (id, store_id FK, parking_lot_id FK, lat, lng, status, nfc_code)
parking_sessions (id, device_id FK, user_id FK?, detected_at, authenticated_at?, exited_at?, status, issued_coupon_id FK?)
coupons (id, user_id FK, store_id FK, title, benefit, issued_at, expires_at, used_at?, status, distance_tier)
```

---

## 6. 統合の進め方（双方合意前提）

1. このドキュメントをレビュー、未確定事項（§0）を埋める
2. サーバ側でスキーマ設計・API実装
3. アプリ側で `HttpApiClient`（または `SupabaseApiClient`）を `ApiClient` を implements して実装
4. `lib/core/api/api_providers.dart` の `apiClientProvider` を環境変数で切替可能に
5. **読み取り系** (`getParkingLots` / `getStores`) から段階的に実接続へ切替
6. 書き込み系（認証・クーポン発行）は IoT連携テスト含めて後フェーズで
