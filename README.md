# 🚲 BicycleGo

「駐輪場が空いていない → 放置自転車につながる」問題を、**地図 × インセンティブ（クーポン）** で解決する駐輪支援アプリです。
ユーザーの現在地・駐輪場の空き状況・距離をもとに、**少し遠い駐輪場でも選びたくなる仕組み**を提供します。

---

## 📌 コンセプト

- **罰則ではなくご褒美**で正規駐輪を促す
- 提携店舗のクーポンを**広告チャネル**として活用
- 少し遠くに停めるほど豪華なクーポン → **隠れた名店との出会い**を創出

---

## 🎯 解決したい課題

- 近くの駐輪場が満車だと遠くまで行くのが面倒 → 放置自転車が発生
- 駐輪場の稼働率が偏っており、空きリソースが使われていない
- 提携店舗側も「近くを通っているのに気付かれない」機会損失を抱えている

---

## 🗺 アプリ構成

ボトムナビゲーションで3タブ構成です。

| タブ | 画面 | 役割 |
| --- | --- | --- |
| 地図 | [ParkingMapPage](lib/features/parking/presentation/parking_map_page.dart) | 駐輪場・配信中クーポンの地図表示 + 駐輪開始導線 |
| クーポン | [CouponListPage](lib/features/coupons/presentation/coupon_list_page.dart) | 配信中／利用可能／使用済／期限切れクーポン一覧 |
| マイページ | [MyPage](lib/features/mypage/presentation/my_page.dart) | ポイント残高・所持クーポン・メニュー |

---

## 🛠 実装済み機能

### 地図ページ
- 大阪駅周辺を初期表示するGoogle Maps
- **駐輪場マーカー**（稼働率で色分け：緑=空き／橙=混雑／赤=満車近い）
- **クーポンマーカー**（タグ形カスタムアイコン・駐輪場と一目で区別可能）
- **現在地復帰ボタン**
- **駐輪場検索バー**（名称の部分一致）
- **配信中クーポンストリップ**（下端の横スクロールカード）
  - 表示／非表示トグル付き（地図を広く見たいときに格納可能）
- 駐輪場タップで詳細ボトムシート表示
- クーポンマーカータップで店舗プレビューシート表示

### 駐輪場詳細シート [ParkingDetailSheet](lib/features/parking/presentation/parking_detail_sheet.dart)
- 空き／収容／料金の3カラム表示
- 稼働率プログレスバー（色は稼働率と連動）
- 現在地からの距離・徒歩時間
- 更新時刻チップ
- 「ここに停める」「NFCで計測開始」2ボタン構成

### 店舗プレビューシート [StorePreviewSheet](lib/features/stores/presentation/store_preview_sheet.dart)
- 配信中バッジ・カテゴリチップ・レコメンド星スコア
- 特典内容をグラデーションカードで強調
- 「15分駐輪で自動発行」の説明テキスト

### NFC認証シート [NfcLockSheet](lib/features/nfc/presentation/nfc_lock_sheet.dart)
- NFCタグ読み取り（iOS未対応時はデモモードで自動進行）
- ステージ遷移：`待機中 → 認証中 → 成功／エラー`
- 各ステージでアクセントカラーとアイコンが切り替わる
- GPS位置情報とデバイスIDを組み合わせて認証
- エラー時は「もう一度」で再スキャン可能

### 計測中画面 [SessionTimerPage](lib/features/sessions/presentation/session_timer_page.dart)
- 認証完了から**15分カウントダウン**
- 円形プログレスインジケータで残り時間を視覚化
- 対象店舗カード（特典プレビュー付き）
- 15分経過時に自動で `evaluateEarn` を呼び出しクーポン発行
- キャンセル時はセッション破棄して地図に戻る

### クーポン獲得画面 [CouponEarnedPage](lib/features/sessions/presentation/coupon_earned_page.dart)
- 達成バナー（グラデーション + 祝福アイコン）
- 発行されたクーポンの大型カード表示（店舗・特典・有効期限）
- **スワイプto消込**（`SwipeToUse`ウィジェット・店舗スタッフ面前で利用）
- 「あとで使う」でマイページのクーポン一覧へ保存

### クーポン一覧 [CouponListPage](lib/features/coupons/presentation/coupon_list_page.dart)
- セクション別表示：**配信中 / 利用可能 / 使用済み / 期限切れ**
- 配信中クーポンは店舗一覧から（未取得でも閲覧可能）
- プルダウンで手動リフレッシュ
- 空状態の専用イラスト

### マイページ [MyPage](lib/features/mypage/presentation/my_page.dart)
- ポイント残高カード（グラデーションヒーロー）
- 「交換する」ボタン（準備中）
- 利用可能クーポンの一覧表示（タップで詳細想定）
- 駐輪履歴・設定メニュー（準備中）

---

## 🔄 主要フロー

```
駐輪場マーカー選択
  ↓ 「NFCで計測開始」
NFC認証シート（タグ読み取り + GPS照合）
  ↓ 認証成功
計測中画面（15分カウントダウン）
  ↓ 15分経過
クーポン獲得画面
  ↓ スワイプ消込
クーポン使用完了 → 地図に戻る
```

5分以内にNFC認証されなかった場合はセッション失効（`AuthGraceExpiredException`）。
GPSが駐輪場から80m以上離れている場合は `GpsMismatchException`。

---

## 🎨 デザインシステム

- **軽量グラスモーフィズム** — `BackdropFilter`を使わず、半透明塗り + 細いボーダー + 柔らかい影で表現（GPU負荷を最小化）
- **カラーパレット** — [app_colors.dart](lib/core/theme/app_colors.dart) に集約（青×紫のグラデ基調）
- **ガラス装飾** — [glass_decoration.dart](lib/core/theme/glass_decoration.dart) で再利用可能な `BoxDecoration` を提供
- **テーマ** — [app_theme.dart](lib/core/theme/app_theme.dart) でMaterial 3 + Google Fonts（Inter / Noto Sans JP）統一

---

## 🧱 アーキテクチャ

```
lib/
├── app.dart               # MaterialApp・テーマ適用
├── main.dart              # エントリポイント（ProviderScope）
├── routes.dart            # ルート定義
├── core/
│   ├── api/               # ApiClient抽象 + MockApiClient実装
│   ├── theme/             # カラー・グラス装飾・テーマ
│   └── widgets/, utils/   # 共通ウィジェット・ユーティリティ
└── features/
    ├── parking/           # 駐輪場・セッション・地図
    ├── stores/            # 提携店舗
    ├── coupons/           # クーポン・スワイプ消込
    ├── sessions/          # 計測タイマー・獲得演出
    ├── nfc/               # NFC認証シート
    ├── points/            # ポイント残高
    ├── user/              # ユーザー情報
    ├── mypage/            # マイページ
    └── home/              # ボトムナビシェル
```

**状態管理** — Riverpod (`flutter_riverpod ^2.5.1`)
**API層** — `ApiClient` 抽象 + `MockApiClient` 実装。`apiClientProvider` 1箇所を差し替えるだけでHTTP実装に移行可能
**API契約ドキュメント** — [docs/api_contract.md](docs/api_contract.md)

---

## 🛠 技術スタック

### フロントエンド
- **Flutter 3.x / Dart**（Material 3）
- **flutter_riverpod** — 状態管理
- **google_maps_flutter** — 地図表示
- **geolocator** — 位置情報取得
- **nfc_manager** — NFCタグ読み取り（`third_party/` にローカルフォーク）
- **google_fonts** — Inter / Noto Sans JP

### バックエンド（現状）
- **モック実装**（`MockApiClient`）でフロント開発を先行
- データベース選定は未確定（Supabaseが候補）

### デバイス連携（想定）
- NFCタグ付き駐輪ロック装置
- IoTデバイスから `/api/parking/detect` に検知イベント送信

---

## 🚀 セットアップ

```bash
# 依存取得
flutter pub get

# iOS Pods
cd ios && pod install && cd ..

# 実行（エミュレータまたは実機）
flutter run
```

Google Maps APIキーを `ios/Runner/AppDelegate.swift` / `android/app/src/main/AndroidManifest.xml` に設定してください。

---

## 📦 モックデータ

- 駐輪場 — [parking_mock_data.dart](lib/features/parking/data/parking_mock_data.dart)
- 店舗 — [stores/data/store_mock_data.dart](lib/features/stores/data/store_mock_data.dart)
- いずれも大阪駅周辺の緯度経度でシード済み

---

## 🚧 未確定・今後の検討事項

- データベース選定・バックエンド実装（Supabase想定・担当者別）
- クーポン内容と距離のマッピングロジック確定
- ポイント交換UIと交換商品ラインナップ
- 駐輪履歴画面・設定画面の実装
- オンボーディング／初回チュートリアル
- 実機駐輪場データの取得方法（API連携 or 手動登録）

---

## 📝 仕様メモ

### NFCタグ（iOS HIG準拠）
- 「かざす」「接触する」などの語を避け、`スキャン` を使う
- NFCという技術用語ではなく一般的な表現（例：ICカード）を併用
- スキャンシート文言は簡潔に保つ

### 距離計算の方針
- 意思決定時点の現在地をスナップショットとして使用
- リアルタイム追跡は行わない
- NFCタッチ時に距離評価を確定（到着後の現在地更新で不整合が生じるのを防ぐ）
