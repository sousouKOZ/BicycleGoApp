/// 認証まわりの定数。
///
/// メール確認・パスワード再設定のディープリンクで使うリダイレクト URL は、
/// クラウド Supabase の Authentication → URL Configuration → Redirect URLs に
/// 同じ値を登録しておく必要がある（サーバ担当へ依頼）。

/// ディープリンクのカスタムスキーム。ネイティブ（AndroidManifest / Info.plist）にも
/// 同じ scheme/host を登録する（Phase 2）。
const String kAuthScheme = 'io.supabase.bicyclego';
const String kAuthHost = 'login-callback';

/// メール確認・パスワード再設定リンクの戻り先（Phase 2 で使用）。
const String kAuthRedirectUrl = '$kAuthScheme://$kAuthHost';

/// パスワードの最小文字数（Supabase 既定は 6）。
const int kMinPasswordLength = 6;
