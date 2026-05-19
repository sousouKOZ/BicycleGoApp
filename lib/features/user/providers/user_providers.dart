import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/user_profile.dart';

/// 現在のユーザーID（Supabase Auth の anonymous user id UUID）。
///
/// アプリ全体でこのプロバイダ経由でユーザー ID を取得する。
/// main.dart で signInAnonymously 済みなので currentUser は通常非 null。
final currentUserIdProvider = Provider<String>((ref) {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('Supabase user not signed in');
  }
  return user.id;
});

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
    // 端末ローカルから先に読む（ネット切れでも即座に表示するため）
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, Object?>;
        state = UserProfile.fromJson(map);
      } catch (_) {}
    }
    // サーバ側を真実の源として上書き
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      final row = await client
          .from('users')
          .select('nickname, updated_at')
          .eq('id', userId)
          .maybeSingle();
      final nickname = (row?['nickname'] as String?) ?? '';
      if (nickname.isNotEmpty || raw == null) {
        state = UserProfile(
          nickname: nickname,
          updatedAt: row?['updated_at'] != null
              ? DateTime.parse(row!['updated_at'] as String)
              : DateTime.now(),
        );
        await prefs.setString(_key, jsonEncode(state.toJson()));
      }
    } catch (_) {
      // ネットワーク失敗時は端末ローカル値のまま
    }
  }

  Future<void> setNickname(String nickname) async {
    final trimmed = nickname.trim();
    state = UserProfile(nickname: trimmed, updatedAt: DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(state.toJson()));
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId != null) {
        await client.from('users').update({'nickname': trimmed}).eq('id', userId);
      }
    } catch (_) {
      // 失敗しても端末ローカルには保存済み（次回起動時に再同期試行）
    }
  }
}

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>(
  (_) => UserProfileNotifier(),
);
