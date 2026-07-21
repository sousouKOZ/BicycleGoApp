import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/active_parking_info.dart';
import '../../../core/domain/coupon.dart';
import '../../../core/domain/parking_session.dart';

export '../../../core/domain/active_parking_info.dart';

/// 現在利用中の駐輪トランザクション。
/// NFC認証成功で生成され、出庫完了 or スワイプ消込で null に戻す。
final activeSessionProvider = StateProvider<ParkingSession?>((ref) => null);

/// 15分経過時に発行された最新クーポン（タイマ画面→獲得画面の橋渡し）。
final latestEarnedCouponProvider = StateProvider<Coupon?>((ref) => null);

final activeParkingInfoProvider =
    StateProvider<ActiveParkingInfo?>((ref) => null);

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
