import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/providers/auth_providers.dart';
import '../domain/user_profile.dart';

/// 現在のユーザーID（Supabase Auth の user id UUID）。
///
/// アプリ全体でこのプロバイダ経由でユーザー ID を取得する。
/// main.dart で signInAnonymously 済みなので currentUser は通常非 null。
/// authStateProvider を watch して、ログイン/ログアウトでユーザーが切り替わった
/// 際に再評価され、別端末ログイン後も新しい uid を返す。
final currentUserIdProvider = Provider<String>((ref) {
  ref.watch(authStateProvider);
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) {
    throw StateError('Supabase user not signed in');
  }
  return user.id;
});

/// アプリインストール単位の識別子。初回起動時にランダム生成し
/// `shared_preferences` に永続化する（プロフィール画面の表示・問い合わせ用）。
///
/// 駐輪スタンド（IoT デバイス）の deviceId とは別物なので注意。
/// 永続キーは互換のため `device_id_v1` のまま。
final installIdProvider = FutureProvider<String>((ref) async {
  const key = 'device_id_v1';
  final prefs = await SharedPreferences.getInstance();
  final existing = prefs.getString(key);
  if (existing != null && existing.isNotEmpty) return existing;
  final next = _generateInstallId();
  await prefs.setString(key, next);
  return next;
});

String _generateInstallId() {
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

  // 旧来の uid 非スコープのキャッシュキー。アカウントを切り替えても前ユーザーの
  // ニックネームが残ってしまう原因だったため廃止し、_load 時に破棄する。
  static const _legacyKey = 'user_profile_v1';

  /// 端末ローカルのプロフィールキャッシュは uid 別にスコープする。
  /// 同じ端末で別アカウントに切り替えても、前のユーザー名を引き継がない。
  static String _cacheKey(String userId) => 'user_profile_v1_$userId';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    // 旧キーは混線の原因になるので破棄（このユーザーの値は uid 別キーで持つ）。
    await prefs.remove(_legacyKey);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final key = _cacheKey(userId);

    // このユーザー分のローカルキャッシュを先に読む（ネット切れでも即座に表示）。
    final raw = prefs.getString(key);
    if (raw != null) {
      try {
        state = UserProfile.fromJson(jsonDecode(raw) as Map<String, Object?>);
      } catch (_) {}
    }

    // サーバを真実の源として「無条件に」上書きする。
    // 新規アカウントは nickname が空なので、ここで空に正されて「ゲスト」表示になる
    // （以前は空だと上書きをスキップし、前アカウントの名前が残っていた）。
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('nickname, updated_at')
          .eq('id', userId)
          .maybeSingle();
      state = UserProfile(
        nickname: (row?['nickname'] as String?) ?? '',
        updatedAt: row?['updated_at'] != null
            ? DateTime.parse(row!['updated_at'] as String)
            : DateTime.now(),
      );
      await prefs.setString(key, jsonEncode(state.toJson()));
    } catch (_) {
      // ネットワーク失敗時は端末ローカル値のまま
    }
  }

  Future<void> setNickname(String nickname) async {
    final trimmed = nickname.trim();
    state = UserProfile(nickname: trimmed, updatedAt: DateTime.now());
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    final prefs = await SharedPreferences.getInstance();
    if (userId != null) {
      await prefs.setString(_cacheKey(userId), jsonEncode(state.toJson()));
    }
    try {
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
