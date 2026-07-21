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

  /// [from] から [to] を向く方位角（真北 0°、時計回り 0〜360）。
  /// ナビのカメラ回転・進行方向アイコンの向きに使う。
  static double bearingDegrees(LatLng from, LatLng to) {
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);
    final dLng = _toRadians(to.longitude - from.longitude);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    final deg = math.atan2(y, x) * (180.0 / math.pi);
    return (deg + 360.0) % 360.0;
  }
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
