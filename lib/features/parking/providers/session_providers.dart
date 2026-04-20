import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coupons/domain/coupon.dart';
import '../domain/parking_session.dart';

/// 現在利用中の駐輪トランザクション。
/// NFC認証成功で生成され、出庫完了 or スワイプ消込で null に戻す。
final activeSessionProvider = StateProvider<ParkingSession?>((ref) => null);

/// 15分経過時に発行された最新クーポン（タイマ画面→獲得画面の橋渡し）。
final latestEarnedCouponProvider = StateProvider<Coupon?>((ref) => null);
