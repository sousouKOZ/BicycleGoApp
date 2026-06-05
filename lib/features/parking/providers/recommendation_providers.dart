import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/utils/geo.dart';
import '../../../core/domain/store.dart';
import '../../../core/domain/parking_lot.dart';

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

const _couponRadiusMeters = 2000.0;
const _distanceBonusFullAt = 2000.0; // 2000m以上離れていればボーナス最大

/// ユーザーの現在地周辺のおすすめ店舗一覧をPython APIから取得するプロバイダ
final recommendedStoresProvider = FutureProvider.family<List<Store>, LatLng>((ref, userLocation) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getRecommendations(userLocation.latitude, userLocation.longitude);
});

/// 指定した駐輪場に対するレコメンドスコアを計算する関数（APIからのデータを使用）
ParkingRecommendation computeRecommendation({
  required ParkingLot parking,
  required List<Store> recommendedStores, // APIから返ってきたおすすめ店舗
  required LatLng? userLocation,
}) {
  // 駐輪場から2000m以内のおすすめ店舗を抽出し、UI表示用には上位3件に絞る
  var nearby = recommendedStores
      .where((s) =>
          Geo.haversineMeters(parking.position, s.position) <=
          _couponRadiusMeters)
      .toList();
      
  if (nearby.length > 3) {
    nearby = nearby.sublist(0, 3);
  }

  if (nearby.isEmpty) {
    return const ParkingRecommendation(
      score: 0,
      nearbyStores: [],
      bonusPointsPercent: 0,
    );
  }

  // Python APIから付与された finalScore を利用（無ければ recommendWeight にフォールバック）
  final couponScore = nearby
      .map((s) => s.finalScore ?? s.recommendWeight)
      .fold<double>(0, (acc, w) => acc + w)
      .clamp(0, 5.0);
  final normalizedCoupon = couponScore / 5.0;

  double distanceBonus = 0.5;
  int bonusPercent = 0;
  if (userLocation != null) {
    final distance = Geo.haversineMeters(userLocation, parking.position);
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
