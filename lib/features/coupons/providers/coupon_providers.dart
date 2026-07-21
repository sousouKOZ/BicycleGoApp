import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../user/providers/user_providers.dart';
import '../../../core/domain/coupon.dart';

final userCouponsProvider = FutureProvider<List<Coupon>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final userId = ref.watch(currentUserIdProvider);
  return api.getUserCoupons(userId);
});

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
