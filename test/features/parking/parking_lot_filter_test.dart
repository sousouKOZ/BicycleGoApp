import 'package:bicycle_go/core/domain/parking_lot.dart';
import 'package:bicycle_go/core/domain/store.dart';
import 'package:bicycle_go/features/parking/domain/map_filter.dart';
import 'package:bicycle_go/features/parking/domain/parking_lot_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  // 大阪駅周辺の座標。緯度 0.01 度 ≒ 1.1km。
  const origin = LatLng(34.7025, 135.4959);

  ParkingLot lot({
    required String id,
    LatLng position = origin,
    int capacity = 10,
    int occupied = 0,
  }) {
    return ParkingLot(
      id: id,
      name: '駐輪場 $id',
      position: position,
      capacity: capacity,
      occupied: occupied,
      priceYenPerDay: 100,
      updatedAt: DateTime(2026, 6, 1),
    );
  }

  Store store({required String id, LatLng position = origin}) {
    return Store(
      id: id,
      name: '店舗 $id',
      category: StoreCategory.cafe,
      position: position,
      benefit: 'ドリンク 100円OFF',
      recommendWeight: 0.5,
    );
  }

  List<ParkingLot> run({
    required List<ParkingLot> lots,
    String normalizedQuery = '',
    MapFilter filter = const MapFilter(),
    Set<String> favoriteIds = const {},
    List<Store> stores = const [],
  }) {
    return filterParkingLots(
      lots: lots,
      normalizedQuery: normalizedQuery,
      filter: filter,
      favoriteIds: favoriteIds,
      stores: stores,
      origin: origin,
    );
  }

  group('filterParkingLots', () {
    test('条件なしなら全件返す', () {
      final lots = [lot(id: 'a'), lot(id: 'b')];
      expect(run(lots: lots), lots);
    });

    test('検索文字列は名前の部分一致（小文字化済み前提）', () {
      final umeda = ParkingLot(
        id: 'a',
        name: '梅田 駐輪場',
        position: origin,
        capacity: 10,
        occupied: 0,
        priceYenPerDay: 100,
        updatedAt: DateTime(2026, 6, 1),
      );
      final lots = [umeda, lot(id: 'b')];
      expect(run(lots: lots, normalizedQuery: '梅田'), [umeda]);
      expect(run(lots: lots, normalizedQuery: '難波'), isEmpty);
    });

    test('availableOnly は満車を除外', () {
      final open = lot(id: 'open', occupied: 5);
      final full = lot(id: 'full', occupied: 10);
      final result = run(
        lots: [open, full],
        filter: const MapFilter(availableOnly: true),
      );
      expect(result, [open]);
    });

    test('favoriteOnly はお気に入りIDのみ', () {
      final fav = lot(id: 'fav');
      final other = lot(id: 'other');
      final result = run(
        lots: [fav, other],
        filter: const MapFilter(favoriteOnly: true),
        favoriteIds: {'fav'},
      );
      expect(result, [fav]);
    });

    test('within5MinutesOnly は origin から 1250m 以内', () {
      final near = lot(id: 'near'); // origin と同地点
      // 約 5.5km 北
      final far = lot(id: 'far', position: const LatLng(34.7525, 135.4959));
      final result = run(
        lots: [near, far],
        filter: const MapFilter(within5MinutesOnly: true),
      );
      expect(result, [near]);
    });

    test('couponOnly は 300m 以内に店舗がある駐輪場のみ', () {
      final withStore = lot(id: 'with');
      // 約 1.1km 北（店舗圏外）
      final without =
          lot(id: 'without', position: const LatLng(34.7125, 135.4959));
      final result = run(
        lots: [withStore, without],
        filter: const MapFilter(couponOnly: true),
        stores: [store(id: 's1')],
      );
      expect(result, [withStore]);
    });

    test('複数条件は AND で絞り込む', () {
      final match = lot(id: 'match', occupied: 1);
      final fullFav = lot(id: 'full', occupied: 10);
      final result = run(
        lots: [match, fullFav],
        filter: const MapFilter(availableOnly: true, favoriteOnly: true),
        favoriteIds: {'match', 'full'},
      );
      expect(result, [match]);
    });
  });

  group('ParkingLot.usageLevel', () {
    test('85% 以上は high', () {
      expect(lot(id: 'a', occupied: 9).usageLevel, UsageLevel.high); // 90%
      expect(
        lot(id: 'b', capacity: 100, occupied: 85).usageLevel,
        UsageLevel.high,
      );
    });

    test('60% 以上 85% 未満は mid', () {
      expect(
        lot(id: 'a', capacity: 100, occupied: 60).usageLevel,
        UsageLevel.mid,
      );
      expect(
        lot(id: 'b', capacity: 100, occupied: 84).usageLevel,
        UsageLevel.mid,
      );
    });

    test('60% 未満は low（capacity 0 は 0% 扱い）', () {
      expect(
        lot(id: 'a', capacity: 100, occupied: 59).usageLevel,
        UsageLevel.low,
      );
      expect(lot(id: 'b', capacity: 0, occupied: 0).usageLevel, UsageLevel.low);
    });
  });
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
