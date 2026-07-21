import 'package:bicycle_go/core/domain/parking_lot.dart';
import 'package:bicycle_go/core/domain/store.dart';
import 'package:bicycle_go/features/parking/providers/recommendation_providers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// レコメンドエンジンの選定ロジック（仕様書 No.45）。
/// クーポン選定スコアの計算は画面に出ない内部処理のため、ログ証跡で確認する。
const _parkingPos = LatLng(34.700, 135.500);

ParkingLot buildParking() {
  return ParkingLot(
    id: 'lot-1',
    name: 'テスト駐輪場',
    position: _parkingPos,
    capacity: 10,
    occupied: 0,
    priceYenPerDay: 100,
    updatedAt: DateTime(2026, 6, 1),
  );
}

Store buildStore({
  required String id,
  required LatLng position,
  double recommendWeight = 0.5,
  double? finalScore,
}) {
  return Store(
    id: id,
    name: '店舗$id',
    category: StoreCategory.cafe,
    position: position,
    benefit: '10%OFF',
    recommendWeight: recommendWeight,
    finalScore: finalScore,
  );
}

void main() {
  group('computeRecommendation', () {
    test('2000m以内に店舗が無ければスコア0・非推奨', () {
      // 駐輪場から約5.5km離れた店舗のみ。
      final far = buildStore(id: 'far', position: const LatLng(34.700, 135.560));
      final r = computeRecommendation(
        parking: buildParking(),
        recommendedStores: [far],
        userLocation: null,
      );
      expect(r.score, 0);
      expect(r.nearbyStores, isEmpty);
      expect(r.bonusPointsPercent, 0);
      expect(r.isRecommended, isFalse);
    });

    test('近隣店舗の finalScore が高いほど推奨される', () {
      final near = buildStore(
        id: 'near',
        position: const LatLng(34.705, 135.500), // 約556m
        finalScore: 5.0,
      );
      final r = computeRecommendation(
        parking: buildParking(),
        recommendedStores: [near],
        userLocation: null, // 現在地不明時は距離ボーナス0.5固定
      );
      // normalizedCoupon=5/5=1.0 → score = 1.0*0.6 + 0.5*0.4 = 0.8
      expect(r.score, closeTo(0.8, 0.0001));
      expect(r.nearbyStores, hasLength(1));
      expect(r.isRecommended, isTrue);
    });

    test('finalScore が無ければ recommendWeight にフォールバックする', () {
      final near = buildStore(
        id: 'near',
        position: const LatLng(34.705, 135.500),
        recommendWeight: 5.0,
        finalScore: null,
      );
      final r = computeRecommendation(
        parking: buildParking(),
        recommendedStores: [near],
        userLocation: null,
      );
      expect(r.score, closeTo(0.8, 0.0001));
    });

    test('近隣店舗は最大3件に絞られ、スコアもその3件で算出される', () {
      // 全て2000m以内に5件配置。
      final stores = [
        for (var i = 0; i < 5; i++)
          buildStore(
            id: 's$i',
            position: LatLng(34.701 + i * 0.001, 135.500),
            finalScore: 1.0,
          ),
      ];
      final r = computeRecommendation(
        parking: buildParking(),
        recommendedStores: stores,
        userLocation: null,
      );
      expect(r.nearbyStores, hasLength(3));
      // couponScore = 1.0*3 = 3.0 → normalized 0.6 → score = 0.6*0.6 + 0.5*0.4 = 0.56
      expect(r.score, closeTo(0.56, 0.0001));
    });

    test('現在地が遠いほど距離ボーナスが最大(50%)になる', () {
      final near = buildStore(
        id: 'near',
        position: const LatLng(34.705, 135.500),
        finalScore: 5.0,
      );
      final r = computeRecommendation(
        parking: buildParking(),
        recommendedStores: [near],
        // 駐輪場から約6.7km（2000m超）→ 距離ボーナス最大。
        userLocation: const LatLng(34.760, 135.500),
      );
      expect(r.bonusPointsPercent, 50);
      // score = 1.0*0.6 + 1.0*0.4 = 1.0
      expect(r.score, closeTo(1.0, 0.0001));
    });
  });

  group('roundLocationForRecommendation', () {
    test('小数3桁（約100m格子）に丸める', () {
      final rounded =
          roundLocationForRecommendation(const LatLng(34.70049, 135.50051));
      expect(rounded.latitude, closeTo(34.700, 0.0001));
      expect(rounded.longitude, closeTo(135.501, 0.0001));
    });
  });

  group('ParkingRecommendation.isRecommended', () {
    test('しきい値0.45以上で推奨', () {
      const onThreshold = ParkingRecommendation(
        score: 0.45,
        nearbyStores: [],
        bonusPointsPercent: 0,
      );
      const below = ParkingRecommendation(
        score: 0.449,
        nearbyStores: [],
        bonusPointsPercent: 0,
      );
      expect(onThreshold.isRecommended, isTrue);
      expect(below.isRecommended, isFalse);
    });
  });
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
