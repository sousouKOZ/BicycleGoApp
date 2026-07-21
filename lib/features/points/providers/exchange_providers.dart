import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/exchange_catalog_data.dart';
import '../domain/exchange_item.dart';
import '../domain/exchange_record.dart';

final exchangeCatalogProvider = Provider<List<ExchangeItem>>(
  (_) => exchangeCatalog,
);

/// 交換履歴（端末ローカル保存）。同じ端末で別アカウントに切り替えても混ざらないよう
/// uid 別にスコープする（認証切替時に AuthController が invalidate して再読込）。
class ExchangeHistory extends StateNotifier<List<ExchangeRecord>> {
  ExchangeHistory() : super(const <ExchangeRecord>[]) {
    _load();
  }

  // 旧来の uid 非スコープのキー。最初に読み込んだユーザーへ引き継いでから破棄する。
  static const _legacyKey = 'exchange_history_v1';
  static String _cacheKey(String userId) => 'exchange_history_v1_$userId';
  static const _maxRecords = 200;

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = _userId;
    if (userId == null) {
      state = const <ExchangeRecord>[];
      return;
    }
    final key = _cacheKey(userId);
    // 既存（uid 非スコープ）の履歴は、最初に読み込んだユーザーへ引き継いで破棄する。
    if (!prefs.containsKey(key) && prefs.containsKey(_legacyKey)) {
      await prefs.setStringList(
          key, prefs.getStringList(_legacyKey) ?? const <String>[]);
      await prefs.remove(_legacyKey);
    }
    final raw = prefs.getStringList(key) ?? const <String>[];
    final records = <ExchangeRecord>[];
    for (final s in raw) {
      try {
        final map = jsonDecode(s) as Map<String, Object?>;
        records.add(ExchangeRecord.fromJson(map));
      } catch (_) {}
    }
    records.sort((a, b) => b.exchangedAt.compareTo(a.exchangedAt));
    state = records;
  }

  Future<void> _save() async {
    final userId = _userId;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final list = state.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_cacheKey(userId), list);
  }

  Future<void> add(ExchangeRecord record) async {
    final next = [record, ...state];
    if (next.length > _maxRecords) {
      next.removeRange(_maxRecords, next.length);
    }
    state = next;
    await _save();
  }
}

final exchangeHistoryProvider =
    StateNotifierProvider<ExchangeHistory, List<ExchangeRecord>>(
  (_) => ExchangeHistory(),
);

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
