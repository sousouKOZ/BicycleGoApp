import 'package:flutter_riverpod/flutter_riverpod.dart';

enum CouponSortMode {
  /// 獲得が新しい順
  newest,

  /// 有効期限が近い順
  expiringSoon,
}

extension CouponSortModeLabel on CouponSortMode {
  String get label {
    switch (this) {
      case CouponSortMode.newest:
        return '新しい順';
      case CouponSortMode.expiringSoon:
        return '期限が近い順';
    }
  }
}

final couponSortModeProvider = StateProvider<CouponSortMode>(
  (_) => CouponSortMode.newest,
);

final couponSearchQueryProvider = StateProvider<String>((_) => '');
