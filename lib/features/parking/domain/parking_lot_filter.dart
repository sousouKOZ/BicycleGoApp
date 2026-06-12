import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/domain/parking_lot.dart';
import '../../../core/domain/store.dart';
import '../../../core/utils/geo.dart';
import 'map_filter.dart';

/// 自転車の想定速度（≒15km/h）。距離→所要時間の換算に使う。
const bikeMetersPerMinute = 250.0;

/// 「15分以内」フィルタの半径。
const fifteenMinuteBikeRadiusMeters = bikeMetersPerMinute * 15;

/// 「クーポンあり」と見なす駐輪場〜店舗の距離。
const couponProximityMeters = 300.0;

/// 検索文字列と [MapFilter] の条件で駐輪場一覧を絞り込む。
///
/// - [normalizedQuery] は trim + 小文字化済みの検索文字列（空なら全件）。
/// - 「15分以内」は [origin]（現在地が無ければ初期カメラ位置）からの直線距離。
/// - 「クーポンあり」は [couponProximityMeters] 以内に提携店舗がある駐輪場。
List<ParkingLot> filterParkingLots({
  required List<ParkingLot> lots,
  required String normalizedQuery,
  required MapFilter filter,
  required Set<String> favoriteIds,
  required List<Store> stores,
  required LatLng origin,
}) {
  Iterable<ParkingLot> filtered = normalizedQuery.isEmpty
      ? lots
      : lots.where(
          (p) => p.name.toLowerCase().contains(normalizedQuery),
        );
  if (filter.availableOnly) {
    filtered = filtered.where((p) => p.available > 0);
  }
  if (filter.favoriteOnly) {
    filtered = filtered.where((p) => favoriteIds.contains(p.id));
  }
  if (filter.within15MinutesOnly) {
    filtered = filtered.where(
      (p) =>
          Geo.haversineMeters(origin, p.position) <=
          fifteenMinuteBikeRadiusMeters,
    );
  }
  if (filter.couponOnly) {
    filtered = filtered.where((p) {
      for (final s in stores) {
        if (Geo.haversineMeters(p.position, s.position) <=
            couponProximityMeters) {
          return true;
        }
      }
      return false;
    });
  }
  return filtered.toList();
}
