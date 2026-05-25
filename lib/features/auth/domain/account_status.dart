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

  static const guest = AccountStatus(kind: AccountKind.guest);
}
