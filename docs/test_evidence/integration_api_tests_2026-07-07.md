# 結合テスト エビデンス（API 3件）

- **実施日時**: 2026-07-07 16:26〜16:31 JST
- **環境**: 本番 Supabase プロジェクト `xgqsqjzkitjmtpshaslt`（BicycleGoDB）
- **方法**: curl による直接 API 呼び出し + psql 相当（psycopg2）による DB 実体確認
- **テストデータ**: 専用のテストデバイス `d-test-it-01`・テストユーザー `it-test-20260707@example.com`（uid: `8247b331-a425-4e4b-87a4-eef34cd17519`）を作成して実施。**テスト終了後に全て削除済み**（本文末尾のクリーンアップ記録参照）。実デバイス・実ユーザーのデータには一切触れていない。
- **結果サマリ**: 3件すべて **合格（Pass）**

| # | テスト項目 | 期待結果 | 結果 |
|---|-----------|---------|------|
| 1 | POST parking_detect — IoT検知イベントの受信・記録 | HTTP 200/201、検知データがDBに記録 | **Pass**（HTTP 201、DB記録確認済み） |
| 2 | POST parking_auth — 認証要求受信・セッション生成 | 認証成功時にセッションが「計測中」へ遷移 | **Pass**（HTTP 200、`measuring` 遷移・DB確認済み） |
| 3 | GET クーポン一覧 — 保有クーポン取得 | 有効なクーポン一覧が JSON で返却 | **Pass**（HTTP 200、JSON 配列で返却・RLS 動作確認済み） |

## 仕様書（テスト項目表）と現行 API の対応

テスト項目表の記載は設計初期のエンドポイント名/ボディのため、現行実装（`supabase/functions/`）に読み替えて実施した。

| 項目表の記載 | 現行実装 |
|---|---|
| `POST /api/parking/detect`, body `{ device_id, event_type:"detected", timestamp }` | `POST /functions/v1/parking_detect`, body `{ deviceId, detectedAt, status:"entry" }`（認可: DEVICE_INGEST_TOKEN または service_role bearer） |
| `POST /api/parking/auth`, body `{ user_id, device_id, lat, lng }`、「GPS照合」 | `POST /functions/v1/parking_auth`, body `{ deviceId }`。user_id はユーザー JWT から解決。**GPS 照合は設計変更で廃止済み**（屋内・隣接スタンド誤判定対策。[parking_auth/index.ts](../../supabase/functions/parking_auth/index.ts) 冒頭コメント参照）。照合の代替として「5分以内の未認証検知セッションの存在」を認証条件とする |
| `GET /api/user/coupons` | PostgREST `GET /rest/v1/coupons?user_id=eq.<uid>`（ユーザー JWT、RLS で自分の行のみ）。アプリ実装 [supabase_api_client.dart](../../lib/core/api/supabase_api_client.dart) `getUserCoupons` と同一経路 |

---

## TEST 1: POST parking_detect（IoT検知イベント受信・記録）

**事前条件**: デバイス `d-test-it-01` が devices テーブルに登録済み。アクティブセッションなし。

**リクエスト**（16:26:22 JST / 07:26:22 UTC）:

```
POST https://xgqsqjzkitjmtpshaslt.supabase.co/functions/v1/parking_detect
Authorization: Bearer <service_role key（マイコン運用時は DEVICE_INGEST_TOKEN）>
Content-Type: application/json

{"deviceId":"d-test-it-01","detectedAt":"2026-07-07T07:26:22Z","status":"entry"}
```

**レスポンス**: `HTTP/2 201`

```json
{"id":"ses-1783409182804-2ee3558b","device_id":"d-test-it-01","user_id":null,
 "detected_at":"2026-07-07T16:26:22+09:00","authenticated_at":null,"exited_at":null,
 "status":"unauthenticated","issued_coupon_id":null,
 "created_at":"2026-07-07T16:26:22.821686+09:00","long_park_warned_at":null}
```

**DB 実体確認**（parking_sessions を直接 SELECT）:

```
id=ses-1783409182804-2ee3558b, device_id=d-test-it-01, user_id=NULL,
detected_at=2026-07-07 16:26:22+09, status=unauthenticated
devices.last_seen_at=2026-07-07 16:26:22+09  ← 検知時刻で更新されたことも確認
```

**判定**: **Pass** — HTTP 201 が返却され、検知データ（セッション行）が DB に記録された。

## TEST 2: POST parking_auth（認証要求受信・セッション生成）

**事前条件**: TEST 1 で `d-test-it-01` が未認証（`unauthenticated`）セッションを保持。認証猶予（検知から5分）以内。テストユーザーはアクティブセッションを未保有。

**リクエスト**（16:28:18 JST）:

```
POST https://xgqsqjzkitjmtpshaslt.supabase.co/functions/v1/parking_auth
apikey: <anon key>
Authorization: Bearer <テストユーザーの JWT（メール+パスワードでサインインして取得）>
Content-Type: application/json

{"deviceId":"d-test-it-01"}
```

**レスポンス**: `HTTP/2 200`

```json
{"id":"ses-1783409182804-2ee3558b","device_id":"d-test-it-01",
 "user_id":"8247b331-a425-4e4b-87a4-eef34cd17519",
 "detected_at":"2026-07-07T16:26:22+09:00",
 "authenticated_at":"2026-07-07T16:28:18.55+09:00","exited_at":null,
 "status":"measuring","issued_coupon_id":null,
 "created_at":"2026-07-07T16:26:22.821686+09:00","long_park_warned_at":null}
```

**DB 実体確認**:

```
id=ses-1783409182804-2ee3558b, user_id=8247b331-…, status=measuring,
authenticated_at=2026-07-07 16:28:18.55+09
```

**判定**: **Pass** — 認証要求が受理され、セッションに user_id が紐付き、ステータスが「計測中（`measuring`）」へ遷移した。

**補足エビデンス（二重認証ガード）**: 直後に同一ユーザーで再度 parking_auth を呼び出したところ `HTTP/2 409` `{"code":"already_active","message":"user already has an active parking session"}` が返却され、1ユーザー同時1駐輪ガード（2026-06-29 デプロイ）が有効であることも確認した。

## TEST 3: GET クーポン一覧（保有クーポン取得）

**事前条件**: テストユーザーが有効クーポンを保有 — service_role で以下を投入:

```
id=cp-test-it-01, user_id=8247b331-…, store_id=s1, status=owned,
issued_at=2026-07-07 16:29:07+09, expires_at=2026-07-14 16:29:07+09（7日後）
```

**リクエスト**（アプリの `getUserCoupons` と同一経路）:

```
GET https://xgqsqjzkitjmtpshaslt.supabase.co/rest/v1/coupons?user_id=eq.8247b331-a425-4e4b-87a4-eef34cd17519&order=issued_at.desc&select=*
apikey: <anon key>
Authorization: Bearer <テストユーザーの JWT>
```

**レスポンス**: `HTTP/2 200`

```json
[{"id":"cp-test-it-01","user_id":"8247b331-a425-4e4b-87a4-eef34cd17519",
  "store_id":"s1","store_name":"テスト店舗（結合テスト用）","title":"結合テスト用クーポン",
  "benefit":"ドリンク1杯無料","issued_at":"2026-07-07T16:29:07.489798+09:00",
  "expires_at":"2026-07-14T16:29:07.489798+09:00","used_at":null,
  "status":"owned","distance_tier":"near","created_at":"2026-07-07T16:29:07.489798+09:00"}]
```

**判定**: **Pass** — 該当ユーザーの有効クーポン一覧が JSON 形式で返却された。

**補足エビデンス（RLS）**: user_id フィルタ無しの `GET /rest/v1/coupons` でも返却は自ユーザーの1件のみ（この時点で coupons テーブル全体には 5 ユーザー・22 行が存在）。RLS により他ユーザーのクーポンが漏れないことを確認した。

---

## クリーンアップ記録（16:31 JST 完了）

| 対象 | 操作 | 確認 |
|---|---|---|
| クーポン `cp-test-it-01` | DELETE | 削除済み |
| セッション `ses-1783409182804-2ee3558b` | DELETE（`measuring` のまま残さない） | 削除済み。テストユーザー/デバイスに紐づく残存セッション 0 件 |
| デバイス `d-test-it-01` | DELETE | 削除済み |
| ユーザー `it-test-20260707@example.com` | GoTrue Admin API DELETE | HTTP 200 |

parking_sessions のステータス別件数はテスト前後で同一（completed 39 / expired 34 / cancelled 3）であることを確認。業務タイムスタンプの改変（backdating）は行っていない。
