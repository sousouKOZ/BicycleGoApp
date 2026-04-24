import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// お気に入り駐輪場IDの集合を永続化するプロバイダ。
class FavoriteParkings extends StateNotifier<Set<String>> {
  FavoriteParkings() : super(const <String>{}) {
    _load();
  }

  static const _key = 'favorite_parking_ids_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList(_key)?.toSet() ?? const <String>{};
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList());
  }

  Future<void> toggle(String parkingId) async {
    if (state.contains(parkingId)) {
      state = {...state}..remove(parkingId);
    } else {
      state = {...state, parkingId};
    }
    await _save();
  }

  bool isFavorite(String parkingId) => state.contains(parkingId);
}

final favoriteParkingsProvider =
    StateNotifierProvider<FavoriteParkings, Set<String>>(
  (_) => FavoriteParkings(),
);
