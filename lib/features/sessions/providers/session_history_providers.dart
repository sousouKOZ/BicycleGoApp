import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/session_record.dart';

/// セッション履歴を端末ローカルに永続化するプロバイダ。
class SessionHistory extends StateNotifier<List<SessionRecord>> {
  SessionHistory() : super(const <SessionRecord>[]) {
    _load();
  }

  static const _key = 'session_history_v1';
  static const _maxRecords = 200;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const <String>[];
    final records = <SessionRecord>[];
    for (final s in raw) {
      try {
        final map = jsonDecode(s) as Map<String, Object?>;
        records.add(SessionRecord.fromJson(map));
      } catch (_) {}
    }
    records.sort((a, b) => b.completedAt.compareTo(a.completedAt));
    state = records;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final list = state.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_key, list);
  }

  Future<void> add(SessionRecord record) async {
    final next = [record, ...state];
    if (next.length > _maxRecords) {
      next.removeRange(_maxRecords, next.length);
    }
    state = next;
    await _save();
  }

  Future<void> clear() async {
    state = const <SessionRecord>[];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}

final sessionHistoryProvider =
    StateNotifierProvider<SessionHistory, List<SessionRecord>>(
  (_) => SessionHistory(),
);

/// 履歴の集計サマリ。マイページのサマリカードやグラフに使う。
class SessionHistoryStats {
  final int totalSessions;
  final int totalPoints;
  final int monthSessions;
  final int monthPoints;

  const SessionHistoryStats({
    required this.totalSessions,
    required this.totalPoints,
    required this.monthSessions,
    required this.monthPoints,
  });
}

final sessionHistoryStatsProvider = Provider<SessionHistoryStats>((ref) {
  final history = ref.watch(sessionHistoryProvider);
  final now = DateTime.now();
  var monthSessions = 0;
  var monthPoints = 0;
  var totalPoints = 0;
  for (final r in history) {
    totalPoints += r.earnedPoints;
    if (r.completedAt.year == now.year && r.completedAt.month == now.month) {
      monthSessions += 1;
      monthPoints += r.earnedPoints;
    }
  }
  return SessionHistoryStats(
    totalSessions: history.length,
    totalPoints: totalPoints,
    monthSessions: monthSessions,
    monthPoints: monthPoints,
  );
});
