import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../stores/domain/store.dart';
import '../domain/parking_lot.dart';

/// 駐輪場のおすすめ判定結果。
class ParkingRecommendation {
  final double score; // 0.0 - 1.0 にクランプ
  final List<Store> nearbyStores; // 300m以内の店舗
  final int bonusPointsPercent; // 遠距離ボーナス（表示用）

  const ParkingRecommendation({
    required this.score,
    required this.nearbyStores,
    required this.bonusPointsPercent,
  });

  bool get isRecommended => score >= 0.45;
}

const _couponRadiusMeters = 300.0;
const _distanceBonusFullAt = 800.0; // 800m以上離れていればボーナス最大

double _haversineMeters(LatLng a, LatLng b) {
  const earth = 6371000.0;
  double toRad(double d) => d * math.pi / 180.0;
  final dLat = toRad(b.latitude - a.latitude);
  final dLng = toRad(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(toRad(a.latitude)) *
          math.cos(toRad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return earth * 2 * math.asin(math.sqrt(h.toDouble()));
}

ParkingRecommendation computeRecommendation({
  required ParkingLot parking,
  required List<Store> stores,
  required LatLng? userLocation,
}) {
  final nearby = stores
      .where((s) =>
          _haversineMeters(parking.position, s.position) <= _couponRadiusMeters)
      .toList();
  if (nearby.isEmpty) {
    return const ParkingRecommendation(
      score: 0,
      nearbyStores: [],
      bonusPointsPercent: 0,
    );
  }
  final couponScore = nearby
      .map((s) => s.recommendWeight)
      .fold<double>(0, (acc, w) => acc + w)
      .clamp(0, 5.0);
  final normalizedCoupon = couponScore / 5.0;

  double distanceBonus = 0.5;
  int bonusPercent = 0;
  if (userLocation != null) {
    final distance = _haversineMeters(userLocation, parking.position);
    distanceBonus = (distance / _distanceBonusFullAt).clamp(0.0, 1.0);
    bonusPercent = (distanceBonus * 50).round();
  }

  final score = (normalizedCoupon * 0.6 + distanceBonus * 0.4).clamp(0.0, 1.0);
  return ParkingRecommendation(
    score: score,
    nearbyStores: nearby,
    bonusPointsPercent: bonusPercent,
  );
}
