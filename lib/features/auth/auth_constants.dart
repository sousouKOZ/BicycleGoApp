// 認証まわりの定数。
//
// メール確認・パスワード再設定のディープリンクで使うリダイレクト URL は、
// クラウド Supabase の Authentication → URL Configuration → Redirect URLs に
// 同じ値を登録しておく必要がある（サーバ担当へ依頼）。

/// ディープリンクのカスタムスキーム。ネイティブ（AndroidManifest / Info.plist）にも
/// 同じ scheme/host を登録する（Phase 2）。
const String kAuthScheme = 'io.supabase.bicyclego';
const String kAuthHost = 'login-callback';

/// メール確認・パスワード再設定リンクの戻り先（Phase 2 で使用）。
const String kAuthRedirectUrl = '$kAuthScheme://$kAuthHost';

/// パスワードの最小文字数。supabase/config.toml と揃える。
const int kMinPasswordLength = 8;
const String kPasswordRuleLabel = '$kMinPasswordLength文字以上・英字と数字を含む';

bool isPasswordPolicyCompliant(String password) {
  if (password.length < kMinPasswordLength) return false;
  final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
  final hasDigit = RegExp(r'\d').hasMatch(password);
  return hasLetter && hasDigit;
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
