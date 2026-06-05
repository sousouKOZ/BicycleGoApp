import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 地理計算ユーティリティ。
class Geo {
  Geo._();

  static const double earthRadiusMeters = 6371000.0;

  static double _toRadians(double degree) => degree * (math.pi / 180.0);

  /// 2 地点間の大圏距離（メートル）を Haversine 公式で求める。
  static double haversineMeters(LatLng a, LatLng b) {
    final dLat = _toRadians(b.latitude - a.latitude);
    final dLng = _toRadians(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(a.latitude)) *
            math.cos(_toRadians(b.latitude)) *
            math.pow(math.sin(dLng / 2), 2);
    return earthRadiusMeters * 2 * math.asin(math.sqrt(h.toDouble()));
  }
}
