import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/user_profile.dart';

/// プロトタイプ用の固定ユーザID。
/// バックエンド接続時は認証Token（or device ID）から解決する。
final currentUserIdProvider = Provider<String>((ref) => 'user-proto-001');

/// 端末ID。初回起動時にランダム生成し `shared_preferences` に永続化する。
/// アカウント連携が入るまではこの値を匿名IDとして扱う。
final deviceIdProvider = FutureProvider<String>((ref) async {
  const key = 'device_id_v1';
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(key);
  if (existing != null && existing.isNotEmpty) return existing;
  final next = _generateDeviceId();
  await prefs.setString(key, next);
  return next;
});

String _generateDeviceId() {
  final rng = math.Random.secure();
  final bytes =
      List<int>.generate(8, (_) => rng.nextInt(256));
  final hex = bytes
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'dev-$hex';
}

class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier()
      : super(UserProfile(nickname: '', updatedAt: DateTime.now())) {
    _load();
  }

  static const _key = 'user_profile_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, Object?>;
      state = UserProfile.fromJson(map);
    } catch (_) {}
  }

  Future<void> setNickname(String nickname) async {
    state = UserProfile(nickname: nickname.trim(), updatedAt: DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>(
  (_) => UserProfileNotifier(),
);
