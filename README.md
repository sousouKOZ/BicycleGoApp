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
- **位置情報パーミッションバナー** [LocationPermissionBanner](lib/features/parking/presentation/widgets/location_permission_banner.dart)
  - 拒否／拒否（永続）／サービスOFF を [LocationPermissionNotifier](lib/features/parking/providers/location_permission_providers.dart) で4状態に集約
  - 状態別の見出しと CTA — 「位置情報を許可」「設定アプリを開く」「位置情報の設定を開く」
  - dialog 連打を廃止し、検索バー直下のガラス調バナーに集約

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
- NFCタグ読み取り（NFC 非対応端末ではデモモードで自動進行）
- ステージ遷移：`待機中 → 認証中 → 成功／エラー`
- 各ステージでアクセントカラーとアイコンが切り替わる
- **NFC タグの ID（deviceId）一致のみで認証** — 屋内・隣接スタンド誤判定対策で GPS 照合は廃止
- 本番では IoT 検知イベントとの紐付けで強化する想定（[docs/server_implementation.md §13](docs/server_implementation.md)）
- エラー時は「もう一度」で再スキャン可能

### 計測中画面 [SessionTimerPage](lib/features/sessions/presentation/session_timer_page.dart)
- 認証完了から**15分カウントダウン**
- 円形プログレスインジケータで残り時間を視覚化
- 対象店舗カード（特典プレビュー付き）
- **最小化ボタン** — 画面を閉じてもセッションは背景で継続、ミニバーから再展開可能
- 「計測を中止する」で確認ダイアログ → セッション破棄
- **通知OFF時の誘導カード** [_NotificationHint](lib/features/sessions/presentation/session_timer_page.dart)
  - [NotificationPermissionNotifier](lib/features/sessions/providers/notification_permission_providers.dart) を監視
  - 「許可」タップで再リクエスト、再拒否なら設定アプリへ自動遷移

### セッションミニバー [SessionMiniBar](lib/features/sessions/presentation/session_mini_bar.dart)
- 計測中は**ボトムナビゲーションの上に常駐**するグラデーションバー
- 残り時間・プログレスをリアルタイム表示
- **全タブから進捗確認可能**（地図／クーポン／マイページ切替時も表示継続）
- タップで計測画面を再展開
- 15分達成判定・`evaluateEarn` 呼び出し・獲得画面遷移は **HomeShellに集約** — どの画面からでもクーポン獲得画面に自動遷移
- **`parked` モード** — クーポン獲得後も自転車を出していない間は緑グラデの「駐輪中（クーポン獲得済）」バーに切替、累計駐輪時間を表示
  - タップで [CheckoutSheet](lib/features/sessions/presentation/checkout_sheet.dart) を表示
- **アプリ kill 後の状態復元**（Supabase モード）— [HomeShell](lib/features/home/presentation/home_shell.dart) の `_restoreFromServer` で起動時に `getActiveSession` を呼び、measuring / achieved / parked のセッションがあれば即時復元。kill → 再起動でもバーが消えない

### クーポン獲得画面 [CouponEarnedPage](lib/features/sessions/presentation/coupon_earned_page.dart)
- 達成バナー（グラデーション + 祝福アイコン）
- 発行されたクーポンの大型カード表示（店舗・特典・有効期限）
- **スワイプto消込**（`SwipeToUse`ウィジェット・店舗スタッフ面前で利用）
- 「あとで使う（駐輪は継続中）」 — クーポンを保存しつつセッションを `parked` 状態に遷移、ミニバーから出庫操作を継続できる
- **入場時の触覚フィードバック** — `HapticFeedback.heavyImpact()` で達成感を物理的にも演出
- **スパークルバースト** [_SparkleBurst](lib/features/sessions/presentation/coupon_earned_page.dart) — バナー周辺で14個のパーティクルが放射状に拡散（CustomPainter、外部依存なし）
- **シェアボタン** — 達成バナー右肩のアイコン。タップで「#BicycleGo で15分駐輪したら ○○ の『△△』クーポンが届いた！」をクリップボードにコピー（追加パッケージ不要、SNS への貼り付けを想定）
- **アプリ kill 状態でのクーポン受取り**（Supabase モード）— サーバの pg_cron が15分達成を検知して自律発行 → 通知タップでアプリ起動時、[HomeShell._checkUnseenEarnedCoupon](lib/features/home/presentation/home_shell.dart) が未表示の owned クーポンを検知して自動的にこの画面へ遷移

### 出庫シート [CheckoutSheet](lib/features/sessions/presentation/checkout_sheet.dart)
- 駐輪場名・駐輪開始時刻・累計駐輪時間・ステータスを一覧表示
- 「自転車を出す」で `api.endSession` を呼び、履歴の `completedAt` を**実際の出庫時刻**に上書き（[SessionHistory.updateCompletedAt](lib/features/sessions/providers/session_history_providers.dart)）
- セッションを `completed` に遷移しミニバーを消去、駐輪場の空き情報更新トリガとなる
- 「まだ出さない」でシートだけ閉じる（セッションは継続）

### クーポン一覧 [CouponListPage](lib/features/coupons/presentation/coupon_list_page.dart)
- セクション別表示：**配信中 / 利用可能 / 使用済み / 期限切れ**
- 配信中クーポンは店舗一覧から（未取得でも閲覧可能）
- プルダウンで手動リフレッシュ
- 空状態の専用イラスト
- **検索バー** — 店名・特典文の部分一致でフィルタ（[couponSearchQueryProvider](lib/features/coupons/providers/coupon_filter_providers.dart)）
- **並び順トグル** — `新しい順 / 期限が近い順`（[couponSortModeProvider](lib/features/coupons/providers/coupon_filter_providers.dart)）
- カードタップで [CouponDetailPage](lib/features/coupons/presentation/coupon_detail_page.dart) に遷移

### クーポン詳細ページ [CouponDetailPage](lib/features/coupons/presentation/coupon_detail_page.dart)
- ステータスバッジ（利用可能／使用済み／期限切れ）と発行元タグ
- 特典ヒーローカード（`StorePreviewSheet` と統一感のあるグラデ）
- **有効期限カウントダウン** — `あと N日 H時間` 形式で30秒ごとに自動更新
- **「店舗を地図で開く」** — `url_launcher` で Google Maps を外部起動（緯度経度クエリ）
- 利用方法（3ステップ）・クーポン情報テーブル（発行日時／有効期限／使用日時／クーポンID）
- 利用可能なクーポンは画面下部に [SwipeToUse](lib/features/coupons/presentation/widgets/swipe_to_use.dart) を表示、消込後は自動で前画面に戻る
- 使用済み・期限切れは無効状態のラベルカードを表示

### マイページ [MyPage](lib/features/mypage/presentation/my_page.dart)
- ポイント残高カード（グラデーションヒーロー）
- **「交換する」ボタン** — [PointsExchangePage](lib/features/points/presentation/points_exchange_page.dart) に遷移
- 利用可能クーポンの一覧表示（タップで [CouponDetailPage](lib/features/coupons/presentation/coupon_detail_page.dart) へ）
- **お気に入り駐輪場セクション** — 登録済み駐輪場をカード一覧表示、タップで詳細シートを開く（未登録時は誘導文を表示）
- **駐輪履歴メニュー** — 件数バッジ付き、タップで履歴画面に遷移
- **設定メニュー** — テーマ切替・通知権限確認

### ポイント交換 [PointsExchangePage](lib/features/points/presentation/points_exchange_page.dart)
- 残高ヒーローカード + カテゴリ絞り込みチップ（カフェ／グルメ／物販／モビリティ／寄付）
- 商品リスト（[exchangeCatalog](lib/features/points/data/exchange_catalog_data.dart)）
  - 各タイル：アイコン・タイトル・説明・必要ポイント
  - 残高不足の商品は薄表示
- タップで [ExchangeConfirmSheet](lib/features/points/presentation/exchange_confirm_sheet.dart)（必要pt／現在残高／交換後残高を可視化、不足ならボタン無効）
- 交換確定で
  - `api.issueExchangeCoupon` を呼び、**即時 `owned` 状態のクーポン**を発行（駐輪達成と異なり15分待ち不要）
  - ポイント残高を減算
  - [ExchangeHistory](lib/features/points/providers/exchange_providers.dart) に記録（`shared_preferences` に永続化、キー: `exchange_history_v1`）
  - `userCouponsProvider` を invalidate して利用可能クーポンに反映
- 右上の履歴アイコンから [ExchangeHistoryPage](lib/features/points/presentation/exchange_history_page.dart) — 商品名・交換日時・消費pt を時系列表示

### 駐輪履歴 [SessionHistoryPage](lib/features/sessions/presentation/session_history_page.dart)
- 15分達成（クーポン獲得）時に自動記録され、端末ローカルに永続化（キー: `session_history_v1`、最大200件）
- 今月の駐輪回数・今月の獲得ポイント・累計のサマリカード（グラデーションヒーロー）
- 各履歴カード — 駐輪場名・日時・所要分・獲得ポイント・発行クーポンの特典文
- 一括削除ダイアログ付き
- 未獲得時はイラスト付きの空ステート

### 設定 [SettingsPage](lib/features/settings/presentation/settings_page.dart)
- **テーマモード切替** — 端末設定に合わせる／ライト／ダーク の3択。選択は `shared_preferences` に永続化（キー: `app_theme_mode_v1`）
- **通知権限確認** — NotificationService 経由で権限状態を取得してスナックバー表示。結果は [NotificationPermissionNotifier](lib/features/sessions/providers/notification_permission_providers.dart) にも反映され、計測中のヒントカードと同期
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

### 駐輪 → クーポン獲得（Supabase モード）
```
駐輪場マーカー選択
  ↓ 「NFCで計測開始」
NFC認証シート（NFC タグ ID で認証 / 屋内対応のため GPS 照合は廃止）
  ↓ 認証成功 → サーバ側 status='measuring'
計測中画面（15分カウントダウン）+ ローカル通知予約

  ┌── ここでアプリ kill されてもサーバは計測継続 ──┐
  │                                                 │
  │   pg_cron が毎分発火                            │
  │     → status=measuring & 15分超過を検知         │
  │     → 推薦ロジックで店舗選定                    │
  │     → クーポン発行 + status='achieved'          │
  │     → +10pt (point_transactions)                │
  │                                                 │
  └─────────────────────────────────────────────────┘
  ↓ 15分経過 → 通知発火（OS レベル、kill 状態でも届く）
  ↓ 通知タップで起動
HomeShell._restoreFromServer
  ├─ getActiveSession でセッション復元（ミニバー復活）
  └─ _checkUnseenEarnedCoupon で未表示クーポンを検知 → 祝福画面遷移
クーポン獲得画面（haptic + sparkle + share）
  ↓ ① スワイプ消込 — redeem_coupon → status='used' + endSession
  ↓ ② 「あとで使う（駐輪は継続中）」 — セッションは parked
出庫タイミング：ミニバーから CheckoutSheet
  ↓ 「自転車を出す」 → end_session
セッション完了（occupied -1 + 履歴の completedAt 上書き）
```

### ポイント交換
```
マイページ「交換する」
  ↓
PointsExchangePage（カテゴリ絞り込み + 商品リスト）
  ↓ 商品タップ
ExchangeConfirmSheet（残高検証）
  ↓ 「交換する」
issue_exchange_coupon Edge Function → PL/pgSQL RPC で原子的に：
  ├─ 残高ロック取得 + 検証
  ├─ クーポン INSERT (owned, distance_tier='exchange')
  ├─ points 残高減算
  └─ point_transactions に exchange 履歴
  ↓
クーポン一覧の「利用可能」セクションに反映
```

5分以内にNFC認証されなかった場合は `expire_sessions` cron が `expired` 化（`AuthGraceExpiredException`）。

---

## 🎨 デザインシステム

- **軽量グラスモーフィズム** — `BackdropFilter`を使わず、半透明塗り + 細いボーダー + 柔らかい影で表現（GPU負荷を最小化）
- **カラーパレット** — [app_colors.dart](lib/core/theme/app_colors.dart) に集約（青×紫のグラデ基調）
- **ガラス装飾** — [glass_decoration.dart](lib/core/theme/glass_decoration.dart) で再利用可能な `BoxDecoration` を提供
- **テーマ** — [app_theme.dart](lib/core/theme/app_theme.dart) でMaterial 3 + Google Fonts（Inter / Noto Sans JP）統一

---

## 🧱 アーキテクチャ

```
┌─────────────────────────────────────────────┐
│  Flutter アプリ (lib/)                       │
│   ├─ apiClientProvider (DI 切替ポイント)    │
│   │   ├─ MockApiClient   (オフライン UI)    │
│   │   └─ SupabaseApiClient (HTTP/Realtime)  │
│   └─ Riverpod で状態管理                    │
└─────────────────────────────────────────────┘
                  │
       ┌──────────┴──────────────┐
       │ USE_SUPABASE=true 時のみ │
       ▼                         ▼
┌──────────────────┐   ┌──────────────────────┐
│ ローカル Supabase │   │ クラウド Supabase    │
│ (Docker)         │   │ (Tokyo region)       │
│ 開発・テスト用   │   │ 本番運用             │
└──────────────────┘   └──────────────────────┘
       │                         │
       └────────┬────────────────┘
                ▼
   ┌──────────────────────────────────────┐
   │ supabase/                            │
   │  ├─ migrations/  (5マイグレーション)  │
   │  ├─ seed.sql     (駐輪場・店舗等)    │
   │  └─ functions/   (7 Edge Functions)  │
   └──────────────────────────────────────┘
```

### Flutter 側（lib/）

```
lib/
├── app.dart               # MaterialApp・テーマ適用
├── main.dart              # ProviderScope + Supabase.initialize + Anonymous Sign-In
├── routes.dart            # ルート定義
├── core/
│   ├── api/               # ApiClient抽象 + MockApiClient + SupabaseApiClient
│   ├── config/            # APIキー・USE_SUPABASE フラグ読み込み
│   ├── recommendation/    # クーポン推薦スコアリング
│   ├── theme/             # カラー・グラス装飾・テーマ
│   └── widgets/, utils/   # 共通ウィジェット・ユーティリティ
└── features/
    ├── parking/           # 駐輪場・地図・位置情報パーミッション
    ├── stores/            # 提携店舗
    ├── coupons/           # クーポン・詳細ページ・フィルタ・スワイプ消込
    ├── sessions/          # 計測タイマー・獲得演出・出庫シート・通知パーミッション
    ├── nfc/               # NFC認証シート
    ├── points/            # ポイント残高・交換カタログ・交換履歴
    ├── alerts/            # 通知関連プロバイダ
    ├── user/              # ユーザー情報・プロフィール
    ├── mypage/            # マイページ
    ├── settings/          # 設定（テーマ・通知・サポート）
    ├── onboarding/        # 初回起動オンボーディング
    └── home/              # ボトムナビシェル + サーバ状態復元
```

### サーバ側（supabase/）

```
supabase/
├── config.toml                 # ローカル Supabase 設定（Anonymous Auth 有効）
├── seed.sql                    # 駐輪場5・店舗5・デバイス5・カタログ6
├── migrations/
│   ├── initial_schema.sql      # 9テーブル + ENUM + index + auth トリガ
│   ├── rls_policies.sql        # 全テーブル RLS（自分のデータのみ可視）
│   ├── pg_cron_jobs.sql        # 毎分 issue_coupons / expire_sessions
│   ├── exchange_rpc.sql        # ポイント交換アトミック関数
│   └── cron_helper_for_cloud.sql  # Vault 経由で URL/キー解決
└── functions/                  # Edge Functions（Deno + TypeScript）
    ├── _shared/                # 定数・CORS・型・推薦ロジック
    ├── parking_detect/         # IoT 検知 → unauthenticated session 作成
    ├── parking_auth/           # NFC 認証 → measuring 遷移
    ├── issue_coupons/          # 達成判定 + クーポン自律発行（cron 起動）
    ├── expire_sessions/        # 認証猶予クリーンナップ（cron 起動）
    ├── redeem_coupon/          # スワイプ消込
    ├── end_session/            # 出庫 + occupied 減算
    └── issue_exchange_coupon/  # ポイント交換（PL/pgSQL RPC 経由でアトミック）
```

**状態管理** — Riverpod (`flutter_riverpod ^2.5.1`)
**API層** — `ApiClient` 抽象 + 2実装（Mock / Supabase）。`apiClientProvider` 1箇所で切替
**バックエンド** — Supabase（Postgres + Auth + Edge Functions + pg_cron + Realtime）
**API契約ドキュメント** — [docs/api_contract.md](docs/api_contract.md)
**サーバ実装ガイド** — [docs/server_implementation.md](docs/server_implementation.md)

---

## 🛠 技術スタック

### フロントエンド
- **Flutter 3.x / Dart**（Material 3）
- **flutter_riverpod** — 状態管理
- **supabase_flutter** — Supabase Auth / DB / Realtime クライアント
- **google_maps_flutter** — 地図表示
- **geolocator** — 位置情報取得 + 設定アプリ起動
- **nfc_manager** — NFCタグ読み取り（`third_party/` にローカルフォーク）
- **flutter_local_notifications + timezone** — セッション通知の予約
- **shared_preferences** — お気に入り／履歴／オンボーディング状態の永続化
- **url_launcher** — クーポン詳細から外部マップを起動
- **google_fonts** — Inter / Noto Sans JP

### バックエンド（Supabase）
- **Postgres + Row Level Security** — 9テーブル、自分のデータのみ閲覧可
- **Edge Functions（Deno + TypeScript）** — 認証・消込・出庫・交換ロジック
- **pg_cron + pg_net** — 15分達成判定 + クーポン自律発行を毎分スケジュール実行
- **Vault** — Edge Function URL / service_role key を暗号化保管
- **Anonymous Sign-In** — 端末ベースの匿名認証（後でメール認証にアップグレード可）
- **モック実装**（`MockApiClient`）も維持 — オフライン UI 開発・テスト用

### デバイス連携（想定）
- NFCタグ付き駐輪スタンド（屋内対応のため GPS 照合は廃止、deviceId のみで認証）
- IoTセンサーから `parking_detect` Edge Function に検知イベント送信

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

### Supabase ローカル / クラウド構築

#### ローカル開発環境（初回のみ）

```bash
# Supabase CLI と Deno をインストール
brew install supabase/tap/supabase
curl -fsSL https://deno.land/install.sh | sh

# プロジェクト直下で initialize（既に済み）
# supabase init

# Docker Desktop を起動した状態で:
supabase start          # 初回 5〜10分（イメージ pull）

# マイグレーション + シードを適用（手動リセット時）
supabase db reset
```

[env/dev.json](env/dev.example.json) に以下を追加：

```json
{
  "SUPABASE_URL": "http://127.0.0.1:54321",
  "SUPABASE_ANON_KEY": "<supabase status の ANON_KEY>"
}
```

#### クラウド本番環境（初回のみ）

1. https://supabase.com で Organization に参加 → 新規 Project 作成（**Region: Tokyo** 必須）
2. Project 作成時に設定した DB パスワードを保管
3. CLI から認証 + リンク：

```bash
supabase login                                  # ブラウザ認証
supabase link --project-ref <project-ref>       # DB パスワード入力
```

4. ローカルの成果物を本番に反映：

```bash
supabase db push                                # 5マイグレーション適用
supabase db query --linked --file supabase/seed.sql   # シードデータ投入
for fn in parking_detect parking_auth issue_coupons \
          expire_sessions redeem_coupon end_session \
          issue_exchange_coupon; do
  supabase functions deploy "$fn" --no-verify-jwt
done
```

5. クラウド側で手動設定（Studio）：
   - **Authentication → Sign In / Up** → `Allow anonymous sign-ins` を **ON**
   - **Database → Extensions** → `pg_cron` と `pg_net` を **Enable**
   - **Vault** に2つのシークレットを登録：
     - `edge_functions_url` → `https://<project-ref>.supabase.co/functions/v1`
     - `edge_functions_service_role_key` → Project Settings → API の `service_role` key

6. アプリ用に [env/prod.json](env/prod.example.json) を作成：

```json
{
  "SUPABASE_URL": "https://<project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<anon public key>"
}
```

詳細は [docs/server_implementation.md](docs/server_implementation.md) §11 を参照。

---

### 🎬 撮影モード（達成時間を短縮）

プロトタイプ動画やデモ撮影用に、`--dart-define=DEMO=true` を付けて起動すると **15分の達成しきい値が30秒**になります。タイマー画面の円形プログレスも30秒で1周するので動画映えします。

```bash
# 撮影用（30秒で達成 → クーポン獲得画面へ）
flutter run --dart-define-from-file=env/dev.json --dart-define=DEMO=true

# 通常起動（15分達成、変更なし）
flutter run --dart-define-from-file=env/dev.json
```

| タイミング | 撮影モード | 通常 |
| --- | --- | --- |
| NFCタップ → 認証完了 | 即時 | 即時 |
| 経過リマインダ通知 | 20秒後「もう少しで…」 | 10分後 |
| クーポン獲得画面に遷移 | **30秒後** | 15分後 |

実装は [parking_session.dart](lib/features/parking/domain/parking_session.dart) の `_isDemoMode = bool.fromEnvironment('DEMO')` で `earnThreshold` を切り替え。本番ビルドには影響しません（環境変数を渡さなければ常に 15 分）。スナックバー文言と通知予約も `earnThreshold` から動的に計算しているので、撮影モードでも整合します。

> **Supabase モード（後述）と組み合わせる場合**は、サーバ側 Edge Function にも `EARN_THRESHOLD_SECONDS=30` を渡す必要があります（[supabase/functions/.env.demo](supabase/functions/.env.demo)）。クライアント・サーバ両方で短縮しないと cron が 15分を待ってしまいクーポンが出ません。

---

## 🚦 開発ワークフロー（モード3種）

| モード | データ | 認証 | 用途 |
| --- | --- | --- | --- |
| **A. Mock のみ** | メモリ上のモック | 固定 ID | UI 修正・オフライン |
| **B. Supabase 接続** | ローカル Postgres | Anonymous Sign-In | 統合テスト |
| **C. Supabase + DEMO** | ローカル Postgres | Anonymous Sign-In | 撮影・短時間検証 |

### モード A：Mock のみ（一番簡単・サーバ不要）

サーバ起動不要。`apiClientProvider` が [MockApiClient](lib/core/api/mock_api_client.dart) を返す。

```bash
flutter run --dart-define-from-file=env/dev.json
```

### モード B：Supabase 接続（本番に近い動作）

ターミナル3枚を並行で起動：

**ターミナル 1: Docker Desktop を起動**
```bash
open -a Docker   # クジラアイコンが緑になるまで30秒〜1分待つ
```

**ターミナル 2: Supabase ローカルスタック**
```bash
supabase start   # 初回 5〜10分（イメージpull）、2回目以降は20秒
```

**ターミナル 3: Edge Functions（起動中ずっと開いたままにする）**
```bash
supabase functions serve --no-verify-jwt
```

**ターミナル 4: Flutter アプリ**
```bash
flutter run --dart-define-from-file=env/dev.json --dart-define=USE_SUPABASE=true
```

### モード C：Supabase + DEMO（撮影用・30秒達成）

ターミナル 1, 2 はモード B と同じ。3, 4 を以下に差し替え：

**ターミナル 3: Edge Functions（DEMO 設定で起動）**
```bash
supabase functions serve --no-verify-jwt --env-file supabase/functions/.env.demo
```

**ターミナル 4: Flutter アプリ（DEMO フラグ追加）**
```bash
flutter run --dart-define-from-file=env/dev.json --dart-define=USE_SUPABASE=true --dart-define=DEMO=true
```

### 動作確認 URL（モード B/C 時のみ）

| 何を見るか | URL |
| --- | --- |
| Supabase Studio（DB/Auth/Edge を GUI で操作） | http://127.0.0.1:54323 |
| メールテスト用 (Mailpit) | http://127.0.0.1:54324 |
| Edge Function 直接呼び出し | http://127.0.0.1:54321/functions/v1/<関数名> |

### 終了方法

| 終わらせるもの | 操作 |
| --- | --- |
| Flutter アプリ | ターミナル 4 で `q`（または Ctrl+C） |
| Edge Functions | ターミナル 3 で `Ctrl+C` |
| Supabase スタック（DB データ保持） | `supabase stop` |
| Supabase スタック + データ初期化 | `supabase stop --no-backup` |
| Docker Desktop | クジラアイコン → Quit |

### 端末別の Supabase URL（実機/Android 時の注意）

[env/dev.json](env/dev.json) の `SUPABASE_URL` は `127.0.0.1` 固定なので、実行端末によって参照先が変わります。`127.0.0.1` は **端末自身** を指すため、Android 実機やエミュレータから Mac 上のローカル Supabase には届きません。

| 実行端末 | 参照すべき URL |
| --- | --- |
| iOS シミュレータ・macOS・Chrome | `http://127.0.0.1:54321`（そのまま） |
| Android エミュレータ | `http://10.0.2.2:54321` |
| 実機（同一 Wi-Fi） | `http://<Mac の LAN IP>:54321` |

`env/dev.json` を書き換えるのではなく、`--dart-define` で **後勝ち上書き** するのがおすすめです（JSON はコミット対象なので汚さずに済む）：

```bash
# Mac の LAN IP を確認
ipconfig getifaddr en0   # 例: 10.77.97.163

# 実機（Android）で起動
flutter run \
  --dart-define-from-file=env/dev.json \
  --dart-define=USE_SUPABASE=true \
  --dart-define=DEMO=true \
  --dart-define=SUPABASE_URL=http://10.77.97.163:54321
```

実機が同じ Wi-Fi に繋がっていない／macOS ファイアウォールで着信がブロックされている場合は、USB 接続中に限り `adb reverse tcp:54321 tcp:54321` でポート転送する方法もあります（この場合は `SUPABASE_URL` を `127.0.0.1` のまま使えます）。

---

## 📦 モックデータ

- 駐輪場 — [parking_mock_data.dart](lib/features/parking/data/parking_mock_data.dart)
- 店舗 — [stores/data/store_mock_data.dart](lib/features/stores/data/store_mock_data.dart)
- いずれも大阪駅周辺の緯度経度でシード済み

---

## 🚧 未確定・今後の検討事項

- **FCM プッシュ通知**：現状はローカル通知。サーバ自律発行と完全連動させるには [docs/server_implementation.md §7](docs/server_implementation.md) を実装
- 交換商品ラインナップの最終版（現状はモックカタログ6種を seed 投入）
- 実機駐輪場データの取得方法（公開 API 連携 or 手動登録 or IoT 連動）
- 通知センター画面（[features/alerts](lib/features/alerts) は providers のみ存在）
- 店舗ブラウズタブ（カテゴリ別／エリア別の逆引き）
- 駐輪場の混雑予測（時間帯別ヒートマップ）
- メール／Apple／Google 認証へのアップグレード（現状は Anonymous Sign-In のみ）
- 多言語対応（i18n の土台）
- アプリストア提出（iOS / Android）

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

### セッション状態遷移
- `unauthenticated` → NFC検知のみ（認証待ち）
- `measuring` → 認証成功後の15分カウントダウン
- `achieved` → 15分達成・クーポン獲得画面表示中
- `parked` → クーポン獲得後も自転車を出していない（ミニバーは緑モード）
- `completed` → 出庫完了
- `expired` → 5分以内に認証されなかった
- `parked` 中は HomeShell の `_checkSession` が再評価しない（重複発行防止）

### クーポン発行タイミング
- **駐輪達成クーポン** — 15分経過後に発行（距離に応じて `near / far / exchange` tier）
  - 有効期限: 3日
  - **Mock モード**：アプリ側 `home_shell._checkSession` のポーリングで `evaluateEarn` を呼ぶ
  - **Supabase モード**：サーバ pg_cron が毎分自律的に判定 → 発行 → アプリは `_restoreFromServer` / `_checkUnseenEarnedCoupon` で取得（**アプリ kill 状態でも発行される**）
- **ポイント交換クーポン** — `issue_exchange_coupon` Edge Function（PL/pgSQL RPC 経由）で**即時 `owned`** 発行
  - 有効期限: 30日
  - `storeId = 'exchange-{itemId}'` のため地図検索には現れない（クーポン詳細の「店舗を地図で開く」も非表示）

### サーバ × クライアントの責務分担

| 機能 | Mock モード | Supabase モード |
|---|---|---|
| 達成判定（15分経過の検知） | アプリの `_checkSession` 1秒ポーリング | サーバの pg_cron 毎分実行 |
| クーポン発行 | アプリ → MockApiClient（メモリ） | Edge Function `issue_coupons`（atomic） |
| ポイント加算 | アプリでローカル計算 | Edge Function（point_transactions に履歴記録） |
| アプリ kill 後も発行 | ❌（メモリ消失） | ✅（サーバ自律） |
| 機種変更データ引き継ぎ | ❌ | △（同じ Anonymous user でログインできれば） |
