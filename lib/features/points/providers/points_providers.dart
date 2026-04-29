import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/api_config.dart';

/// Mock モード時の初期残高。
const int defaultPoints = 1000;

/// ポイント残高プロバイダ。
///
/// - Mock モード: 初期値 [defaultPoints] からスタート、ローカルで増減
/// - Supabase モード: `points` テーブルから取得、変更後 invalidate で再 fetch
class PointsNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    if (!useSupabase) {
      return defaultPoints;
    }
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) return 0;
    final row = await client
        .from('points')
        .select('balance')
        .eq('user_id', userId)
        .maybeSingle();
    return ((row?['balance'] as num?) ?? 0).toInt();
  }

  /// ローカル残高に加算（Mock モード専用 / Supabase モードではサーバ側更新後に refresh）。
  Future<void> add(int delta) async {
    final current = state.valueOrNull ?? defaultPoints;
    state = AsyncValue.data((current + delta).clamp(0, 1 << 31));
    if (useSupabase) {
      // サーバ側で既に書き換わっているはずなので fetch し直して整合させる。
      ref.invalidateSelf();
    }
  }

  /// サーバから明示的に再 fetch（クーポン交換成功後など）。
  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}

final pointsProvider =
    AsyncNotifierProvider<PointsNotifier, int>(PointsNotifier.new);
