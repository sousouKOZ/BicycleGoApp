import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/domain/coupon.dart';
import '../../user/providers/user_providers.dart';
import '../../parking/providers/recommendation_providers.dart';
import '../providers/coupon_providers.dart';

/// クーポンを消込み、一覧（userCouponsProvider）を再取得する。
///
/// 失敗時はスナックバーで通知したうえで rethrow する。
/// SwipeToUse は onCompleted の例外を受けてスワイプ状態を巻き戻すため、
/// 失敗を握りつぶすと「使用済み表示なのに未消込」になってしまう。
Future<void> redeemCouponAndRefresh(
  WidgetRef ref,
  ScaffoldMessengerState messenger,
  Coupon coupon,
) async {
  final api = ref.read(apiClientProvider);
  final userId = ref.read(currentUserIdProvider);
  try {
    await api.redeemCoupon(userId: userId, couponId: coupon.id);
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('クーポンの使用に失敗しました。通信環境をご確認のうえ再度お試しください。'),
      ),
    );
    rethrow;
  }
  ref.invalidate(userCouponsProvider);
  ref.invalidate(recommendedStoresProvider);
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
