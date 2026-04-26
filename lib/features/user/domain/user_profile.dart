/// 端末ローカルに保存されるユーザープロファイル。
///
/// 現状はバックエンド未接続のため、ニックネームと端末IDのみ。
/// Supabase 等の認証導入時はここに `accountId / email / linkedAt` を加える想定。
class UserProfile {
  final String nickname;
  final DateTime updatedAt;

  const UserProfile({required this.nickname, required this.updatedAt});

  String get displayName => nickname.isEmpty ? 'ゲスト' : nickname;

  String get initial {
    final source = nickname.isEmpty ? 'G' : nickname;
    return source.substring(0, 1).toUpperCase();
  }

  Map<String, Object?> toJson() => {
        'nickname': nickname,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, Object?> j) {
    return UserProfile(
      nickname: (j['nickname'] as String?) ?? '',
      updatedAt:
          DateTime.tryParse((j['updatedAt'] as String?) ?? '') ?? DateTime.now(),
    );
  }
}
