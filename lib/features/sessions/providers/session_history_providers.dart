import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../user/providers/user_providers.dart';
import '../../../core/domain/session_record.dart';

/// 駐輪履歴プロバイダ。
///
/// サーバ `parking_sessions` を真実の源として、自分の発行済みセッションを
/// `ApiClient.getSessionHistory` 経由で取得する。出庫やクーポン発行で
/// 状態が変わった後は `ref.invalidate(sessionHistoryProvider)` で再 fetch する。
class SessionHistory extends AsyncNotifier<List<SessionRecord>> {
  @override
  Future<List<SessionRecord>> build() async {
    final api = ref.watch(apiClientProvider);
    final userId = ref.watch(currentUserIdProvider);
    return api.getSessionHistory(userId);
  }
}

final sessionHistoryProvider =
    AsyncNotifierProvider<SessionHistory, List<SessionRecord>>(
  SessionHistory.new,
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
  final history =
      ref.watch(sessionHistoryProvider).valueOrNull ?? const <SessionRecord>[];
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

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
