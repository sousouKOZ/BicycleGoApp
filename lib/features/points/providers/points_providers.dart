import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ポイント残高プロバイダ。
///
/// 残高はサーバ `points` テーブルが真実の源。
/// 変動は Edge Function (issue_coupons / issue_exchange_coupon) が行うため、
/// クライアントは fetch / refresh しかしない。
class PointsNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
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

  /// サーバから明示的に再 fetch（クーポン交換成功後・NFC 認証後など）。
  Future<void> refresh() async {
    ref.invalidateSelf();
  }

  /// 互換目的のエイリアス。引数 [delta] は使わず、サーバから取り直すだけ。
  /// 既存呼び出し元（parking_detail_sheet, exchange_confirm_sheet）の改修コスト回避用。
  Future<void> add(int delta) async {
    ref.invalidateSelf();
  }
}

final pointsProvider =
    AsyncNotifierProvider<PointsNotifier, int>(PointsNotifier.new);
