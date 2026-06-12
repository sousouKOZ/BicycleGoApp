/// ユーザープロファイル。
///
/// サーバ `users` テーブルを真実の源とし、オフライン表示用に
/// 端末ローカル（SharedPreferences）へもキャッシュされる。
/// アカウント連携状態（メール等）は auth 側の AccountStatus が持つ。
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
