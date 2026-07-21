import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// お気に入り駐輪場IDの集合を永続化するプロバイダ。
///
/// 端末ローカル保存だが、同じ端末で別アカウントに切り替えても混ざらないよう
/// uid 別にスコープする（認証切替時に AuthController が invalidate して再読込）。
class FavoriteParkings extends StateNotifier<Set<String>> {
  FavoriteParkings() : super(const <String>{}) {
    _load();
  }

  // 旧来の uid 非スコープのキー。最初に読み込んだユーザーへ引き継いでから破棄する。
  static const _legacyKey = 'favorite_parking_ids_v1';
  static String _cacheKey(String userId) => 'favorite_parking_ids_v1_$userId';

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _userId;
    if (userId == null) {
      state = const <String>{};
      return;
    }
    final key = _cacheKey(userId);
    // 既存（uid 非スコープ）のお気に入りは、最初に読み込んだユーザーへ引き継ぐ。
    // 以後アカウントを跨いで漏れることはなく、既存データの消失も防げる。
    if (!prefs.containsKey(key) && prefs.containsKey(_legacyKey)) {
      await prefs.setStringList(
          key, prefs.getStringList(_legacyKey) ?? const <String>[]);
      await prefs.remove(_legacyKey);
    }
    state = prefs.getStringList(key)?.toSet() ?? const <String>{};
  }

  Future<void> _save() async {
    final userId = _userId;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_cacheKey(userId), state.toList());
  }

  Future<void> toggle(String parkingId) async {
    if (state.contains(parkingId)) {
      state = {...state}..remove(parkingId);
    } else {
      state = {...state, parkingId};
    }
    await _save();
  }
}

final favoriteParkingsProvider =
    StateNotifierProvider<FavoriteParkings, Set<String>>(
  (_) => FavoriteParkings(),
);

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
