/// アカウントの連携状態。Supabase の auth user から導出する読み取り専用モデル。
enum AccountKind { guest, emailLinked, googleLinked }

class AccountStatus {
  final AccountKind kind;

  /// メール連携済みの場合のメールアドレス。ゲストは null。
  final String? email;

  /// 連携済みのプロバイダ識別子（'email' / 'google' など）。
  final List<String> providers;

  const AccountStatus({
    required this.kind,
    this.email,
    this.providers = const [],
  });

  bool get isGuest => kind == AccountKind.guest;

  /// メール+パスワードのログイン手段を持つか（パスワード変更導線の出し分けに使う）。
  /// email+google 連携でも email identity があれば true。
  bool get hasPasswordLogin =>
      kind == AccountKind.emailLinked || providers.contains('email');

  /// Google が連携済みか。
  bool get hasGoogleLinked => providers.contains('google');

  /// Google 連携を解除できるか（他にログイン手段が残る場合のみ）。
  bool get canUnlinkGoogle => hasGoogleLinked && providers.length > 1;

  /// ニックネーム未設定時に表示名として使うフォールバック。
  /// 実際のゲスト（匿名）だけ「ゲスト」とし、連携済みアカウントは
  /// メールのローカル部（無ければ「ユーザー」）を返す。
  /// ログイン済みなのに「ゲスト」と表示されてしまう混乱を防ぐ。
  String get fallbackDisplayName {
    if (isGuest) return 'ゲスト';
    final e = email;
    if (e != null && e.contains('@')) return e.split('@').first;
    return 'ユーザー';
  }

  static const guest = AccountStatus(kind: AccountKind.guest);
}
