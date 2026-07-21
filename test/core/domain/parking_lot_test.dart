import 'package:bicycle_go/core/domain/parking_lot.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 空き状況・稼働率の算出ロジック（仕様書 No.27/28/31/32 の裏側）。
/// 表示色やバッジは UI で確認するが、その元になる計算値はログ証跡で確認する。
ParkingLot buildLot({required int capacity, required int occupied}) {
  return ParkingLot(
    id: 'lot-1',
    name: 'テスト駐輪場',
    position: const LatLng(34.7, 135.5),
    capacity: capacity,
    occupied: occupied,
    priceYenPerDay: 100,
    updatedAt: DateTime(2026, 6, 1),
  );
}

void main() {
  group('ParkingLot.available（空き台数）', () {
    test('収容 - 利用 を返す', () {
      expect(buildLot(capacity: 10, occupied: 3).available, 7);
    });

    test('利用が収容を超えても 0 未満にならない', () {
      expect(buildLot(capacity: 10, occupied: 12).available, 0);
    });

    test('満車は 0', () {
      expect(buildLot(capacity: 10, occupied: 10).available, 0);
    });
  });

  group('ParkingLot.usageRatePercent（稼働率）', () {
    test('利用/収容を百分率（四捨五入）で返す', () {
      expect(buildLot(capacity: 10, occupied: 5).usageRatePercent, 50);
      expect(buildLot(capacity: 3, occupied: 1).usageRatePercent, 33);
    });

    test('収容0は0%（ゼロ除算を回避）', () {
      expect(buildLot(capacity: 0, occupied: 0).usageRatePercent, 0);
    });
  });

  group('ParkingLot.usageLevel（混雑段階）', () {
    test('60%未満は low', () {
      expect(buildLot(capacity: 100, occupied: 59).usageLevel, UsageLevel.low);
    });

    test('60%以上85%未満は mid（下限60を含む）', () {
      expect(buildLot(capacity: 100, occupied: 60).usageLevel, UsageLevel.mid);
      expect(buildLot(capacity: 100, occupied: 84).usageLevel, UsageLevel.mid);
    });

    test('85%以上は high（下限85を含む）', () {
      expect(buildLot(capacity: 100, occupied: 85).usageLevel, UsageLevel.high);
      expect(buildLot(capacity: 100, occupied: 100).usageLevel, UsageLevel.high);
    });
  });
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
