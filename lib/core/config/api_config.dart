/// 環境変数の集約ポイント。
///
/// すべて `--dart-define-from-file=env/dev.json` 経由で注入される。
/// 値が空の場合は該当機能を無効として扱う。

const directionsApiKey =
    String.fromEnvironment('GOOGLE_DIRECTIONS_API_KEY', defaultValue: '');

/// Supabase バックエンドへの接続を有効化するフラグ。
/// 未指定なら MockApiClient を使う（オフラインで UI 開発可能）。
const useSupabase = bool.fromEnvironment('USE_SUPABASE', defaultValue: false);

/// Supabase プロジェクト URL。`USE_SUPABASE=true` 時のみ参照される。
///   - iOS シミュレータ: http://127.0.0.1:54321
///   - Android エミュレータ: http://10.0.2.2:54321
///   - 実機: http://<MacのLAN IP>:54321
const supabaseUrl =
    String.fromEnvironment('SUPABASE_URL', defaultValue: '');

/// Supabase Anon キー（クライアント公開可能なキー）。
const supabaseAnonKey =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');
