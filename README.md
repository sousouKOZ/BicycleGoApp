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
- **駐輪場検索**
  - 検索バー入力／フォーカス時にガラス調の結果ドロップダウンを表示
  - 名称の部分一致でフィルタ
  - 現在地からの距離順に自動ソート
  - 各結果に空き台数（稼働率で色分け）・稼働率・距離を併記
  - タップで該当駐輪場へカメラズーム + 詳細シート自動表示
  - 地図タップまたは✕ボタンで検索状態をクリア
- **配信中クーポンストリップ**（下端の横スクロールカード）
  - 表示／非表示トグル付き（地図を広く見たいときに格納可能）
- **マーカーフィルタチップ**（検索バー下の横並びトグル）
  - `空きのみ` — 満車の駐輪場を除外
  - `クーポンあり` — 300m以内に提携店舗がある駐輪場のみ表示
  - `お気に入り` — お気に入り登録した駐輪場のみ表示
  - 複数条件のAND適用、検索ワードとも併用可能
- **おすすめ順ソート＋おすすめバッジ** — 検索結果ドロップダウンに `距離順／おすすめ順` トグルと `おすすめ +X%` グラデバッジ
  - スコア = 近隣クーポンの豊富さ × 現在地からの距離（遠いほど高スコア）
  - 「近場が満車でも遠くに停めるご褒美」というコンセプトを視覚化
- 駐輪場タップで詳細ボトムシート表示
- クーポンマーカータップで店舗プレビューシート表示
- **アプリ内ルート表示** — 詳細シートの「経路を見る」で Directions API から自転車経路を取得し、地図上に青いポリラインを描画
  - 取得後に自動でルート全体が収まる範囲へカメラズーム
  - 地図上部に[_RouteBanner](lib/features/parking/presentation/parking_map_page.dart)（駐輪場名・距離・所要時間・×ボタン）を表示
  - ✕タップでポリライン・バナーを一括クリア

### 駐輪場詳細シート [ParkingDetailSheet](lib/features/parking/presentation/parking_detail_sheet.dart)
- 空き／収容／料金の3カラム表示
- 稼働率プログレスバー（色は稼働率と連動）
- 現在地からの距離・徒歩時間
- 更新時刻チップ
- **「経路を見る」ボタン** — Google Directions API で自転車経路を取得し、アプリ内の地図上にポリラインで表示（距離・所要時間のバナーと×ボタン付き）
- **お気に入り★ボタン** — ヘッダーに常設、1タップでお気に入り登録／解除（端末ローカルに永続化）
- **近くで使えるクーポンセクション** — 300m以内の提携店舗をチップ表示、タップで店舗プレビュー。遠距離ボーナス %も表示
- 「NFCで計測開始」ボタンでNFC認証シートを表示

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
- **最小化ボタン** — 画面を閉じてもセッションは背景で継続、ミニバーから再展開可能
- 「計測を中止する」で確認ダイアログ → セッション破棄

### セッションミニバー [SessionMiniBar](lib/features/sessions/presentation/session_mini_bar.dart)
- 計測中は**ボトムナビゲーションの上に常駐**するグラデーションバー
- 残り時間・プログレスをリアルタイム表示
- **全タブから進捗確認可能**（地図／クーポン／マイページ切替時も表示継続）
- タップで計測画面を再展開
- 15分達成判定・`evaluateEarn` 呼び出し・獲得画面遷移は **HomeShellに集約** — どの画面からでもクーポン獲得画面に自動遷移

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
- **お気に入り駐輪場セクション** — 登録済み駐輪場をカード一覧表示、タップで詳細シートを開く（未登録時は誘導文を表示）
- **駐輪履歴メニュー** — 件数バッジ付き、タップで履歴画面に遷移
- **設定メニュー** — テーマ切替・通知権限確認

### 駐輪履歴 [SessionHistoryPage](lib/features/sessions/presentation/session_history_page.dart)
- 15分達成（クーポン獲得）時に自動記録され、端末ローカルに永続化（キー: `session_history_v1`、最大200件）
- 今月の駐輪回数・今月の獲得ポイント・累計のサマリカード（グラデーションヒーロー）
- 各履歴カード — 駐輪場名・日時・所要分・獲得ポイント・発行クーポンの特典文
- 一括削除ダイアログ付き
- 未獲得時はイラスト付きの空ステート

### 設定 [SettingsPage](lib/features/settings/presentation/settings_page.dart)
- **テーマモード切替** — 端末設定に合わせる／ライト／ダーク の3択。選択は `shared_preferences` に永続化（キー: `app_theme_mode_v1`）
- **通知権限確認** — NotificationService 経由で現在の権限状態をスナックバー表示
- **アプリバージョン**表示
- [ダークテーマ実装](lib/core/theme/app_theme.dart) — `ColorScheme.fromSeed(brightness: dark)` ベース、[GlassDecoration](lib/core/theme/glass_decoration.dart) もcontext経由でダーク配色に追従

### お気に入り駐輪場 [FavoriteParkings](lib/features/parking/providers/favorite_providers.dart)
- 駐輪場詳細シートの★タップでトグル
- `shared_preferences` で端末ローカルに永続化（キー: `favorite_parking_ids_v1`）
- 地図の `お気に入り` フィルタ・マイページのセクション表示と連動

### オンボーディング [OnboardingPage](lib/features/onboarding/presentation/onboarding_page.dart)
- 初回起動時に表示される3ステップの PageView
  1. 「近場が満車でも、ちょっと遠くへ」 — コンセプト訴求
  2. 「NFCでサッと計測開始」 — 使い方の説明
  3. 「15分停めるだけでクーポン獲得」 — インセンティブ訴求
- 完了フラグを `shared_preferences` に保存（キー: `onboarding_completed_v1`）し、2回目以降はスキップ
- [app.dart](lib/app.dart) が `onboardingCompletedProvider` を監視して `OnboardingPage` / `HomeShell` を出し分け

### プッシュ通知（ローカル通知）
- 駐輪セッション中、アプリを閉じていてもクーポン発行タイミングを通知
- **10分経過時** — 「もう少しでクーポンが届きます」
- **15分達成時** — 「🎉 クーポンが発行されました」
- セッション開始時（NFC認証成功時）に[NotificationService](lib/features/sessions/data/notification_service.dart)で2本同時予約
- 計測中止・クーポン消込・「あとで使う」で予約キャンセル
- 初回セッション開始時に通知権限を自動リクエスト（iOS / Android 13+）
- `flutter_local_notifications` + `timezone` でサーバー不要 — 後で FCM への差し替えも容易

### セキュリティ構成
- **APIキーの用途別分離** — Maps SDK キー（iOS/Android ネイティブ）と Directions API キー（Dart）を別々に管理
- **キーのソースコード非含有** — すべて gitignore 済みファイルから読み込み
  - iOS: [Secrets.xcconfig](ios/Flutter/Secrets.xcconfig) → Info.plist `$(MAPS_API_KEY)` → `GMSServices.provideAPIKey`
  - Android: [secrets.properties](android/secrets.properties) → Gradle `manifestPlaceholders` → AndroidManifest `${MAPS_API_KEY}`
  - Dart: [env/dev.json](env/dev.json) → `--dart-define-from-file` → [api_config.dart](lib/core/config/api_config.dart)
- **テンプレファイル方式** — `.example` 付きファイルのみコミット、実キーファイルは個人環境でコピー生成
- **VS Code debug 構成** — [.vscode/launch.json](.vscode/launch.json) で `--dart-define-from-file` を自動付与（F5 で即起動）

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

### APIキーの設定（用途別に2種類）

本アプリは Google Cloud Platform のキーを**用途別に2つ**使い分けます。キーはいずれも **gitに含まれないファイル**から読み込む構成になっています。

| 用途 | 有効化するAPI | 格納先 |
| --- | --- | --- |
| 地図描画（iOS/Android） | Maps SDK for iOS / Maps SDK for Android | `ios/Flutter/Secrets.xcconfig` / `android/secrets.properties` |
| 経路取得（Directions） | Directions API | `env/dev.json` |

#### 1. Maps SDK キー（地図描画用）

**iOS** — [ios/Flutter/Secrets.example.xcconfig](ios/Flutter/Secrets.example.xcconfig) をコピーして値を書き換え。

```bash
cp ios/Flutter/Secrets.example.xcconfig ios/Flutter/Secrets.xcconfig
# Secrets.xcconfig の MAPS_API_KEY を編集
```

**Android** — [android/secrets.example.properties](android/secrets.example.properties) をコピーして値を書き換え。

```bash
cp android/secrets.example.properties android/secrets.properties
# secrets.properties の MAPS_API_KEY を編集
```

- iOS は [Info.plist](ios/Runner/Info.plist) の `GMSApiKey` が `$(MAPS_API_KEY)` を参照し、[AppDelegate.swift](ios/Runner/AppDelegate.swift) がそれを読んで `GMSServices.provideAPIKey` に渡します。
- Android は [build.gradle.kts](android/app/build.gradle.kts) で `manifestPlaceholders["MAPS_API_KEY"]` に注入、[AndroidManifest.xml](android/app/src/main/AndroidManifest.xml) の `${MAPS_API_KEY}` に展開されます。

#### 2. Directions API キー（経路取得用）

[env/dev.example.json](env/dev.example.json) をコピーして値を書き換え。

```bash
cp env/dev.example.json env/dev.json
# env/dev.json の GOOGLE_DIRECTIONS_API_KEY を編集
```

実行時は [.vscode/launch.json](.vscode/launch.json) から起動するか、コマンドラインで:

```bash
flutter run --dart-define-from-file=env/dev.json
```

Dart 側では [api_config.dart](lib/core/config/api_config.dart) の `directionsApiKey` として読まれ、[directions_service.dart](lib/features/parking/data/directions_service.dart) で利用されます。

#### 3. GCP 側の制限設定（必須）

各キーは GCP Console → Credentials で以下の制限をかけてください。

- **Maps SDK キー**
  - Application restrictions: iOS Bundle ID (`com.example.bicycle_go`) / Android アプリ（パッケージ名 + SHA-1）
  - API restrictions: Maps SDK for iOS / Maps SDK for Android のみ
- **Directions API キー**
  - Application restrictions: なし（アプリから直接叩くため）／または HTTP Referrers
  - API restrictions: Directions API のみ
  - Quotas: 1日あたり上限を設定しておくと事故時の被害を抑えられる

#### 4. キー漏洩時の対応

万が一 git に誤ってコミットしてしまった場合は：

1. GCP Console で該当キーを **Delete**（無効化）
2. 新しいキーを発行して上記の手順で差し替え
3. git 履歴から削除（`git filter-repo` など）— ただしキー自体は既に漏洩しているため、ローテーションが最優先

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
