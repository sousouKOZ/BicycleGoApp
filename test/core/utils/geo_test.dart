import 'package:bicycle_go/core/utils/geo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 距離順ソート（仕様書 No.29）・レコメンド判定（No.45）の土台となる
/// 大圏距離計算のロジックテスト。画面に依存しないためログ証跡で確認する。
void main() {
  group('Geo.haversineMeters', () {
    test('同一地点は 0m', () {
      const p = LatLng(34.7, 135.5);
      expect(Geo.haversineMeters(p, p), closeTo(0, 0.001));
    });

    test('緯度1度の差は約111.2km', () {
      // 緯度1度 ≒ 地球半径(6371km) × π/180 ≒ 111,195m。
      const a = LatLng(0, 0);
      const b = LatLng(1, 0);
      expect(Geo.haversineMeters(a, b), closeTo(111195, 5));
    });

    test('距離は対称（a→b と b→a が等しい）', () {
      const a = LatLng(34.700, 135.500);
      const b = LatLng(34.710, 135.520);
      expect(
        Geo.haversineMeters(a, b),
        closeTo(Geo.haversineMeters(b, a), 0.001),
      );
    });

    test('近い2点ほど距離が小さい（ソート順の妥当性）', () {
      const origin = LatLng(34.700, 135.500);
      const near = LatLng(34.705, 135.500); // 約556m
      const far = LatLng(34.760, 135.500); // 約6.7km
      expect(
        Geo.haversineMeters(origin, near),
        lessThan(Geo.haversineMeters(origin, far)),
      );
    });
  });
}
