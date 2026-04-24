import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coupons/domain/coupon.dart';
import '../domain/parking_session.dart';

/// 現在利用中の駐輪トランザクション。
/// NFC認証成功で生成され、出庫完了 or スワイプ消込で null に戻す。
final activeSessionProvider = StateProvider<ParkingSession?>((ref) => null);

/// 15分経過時に発行された最新クーポン（タイマ画面→獲得画面の橋渡し）。
final latestEarnedCouponProvider = StateProvider<Coupon?>((ref) => null);

/// 現在セッション中の駐輪場情報（履歴記録に利用）。NFC認証成功時にセットし、セッション終了でクリア。
class ActiveParkingInfo {
  final String parkingId;
  final String parkingName;
  const ActiveParkingInfo({required this.parkingId, required this.parkingName});
}

final activeParkingInfoProvider =
    StateProvider<ActiveParkingInfo?>((ref) => null);
