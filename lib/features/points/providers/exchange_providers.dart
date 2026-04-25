import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/exchange_catalog_data.dart';
import '../domain/exchange_item.dart';
import '../domain/exchange_record.dart';

final exchangeCatalogProvider = Provider<List<ExchangeItem>>(
  (_) => exchangeCatalog,
);

class ExchangeHistory extends StateNotifier<List<ExchangeRecord>> {
  ExchangeHistory() : super(const <ExchangeRecord>[]) {
    _load();
  }

  static const _key = 'exchange_history_v1';
  static const _maxRecords = 200;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
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
    final prefs = await SharedPreferences.getInstance();
    final list = state.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_key, list);
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
