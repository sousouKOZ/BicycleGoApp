import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../navigation/domain/nav_step.dart';

class DirectionsRoute {
  final String parkingLotId;
  final String parkingName;
  final LatLng origin;
  final LatLng destination;

  /// 各 step のポリラインを連結した詳細経路。
  /// overview_polyline は間引かれていて経路スナップの精度が出ないため使わない。
  final List<LatLng> polyline;

  final int distanceMeters;
  final int durationSeconds;

  /// 曲がり角ごとの区間。ターンバイターン案内に使う。
  final List<NavStep> steps;

  const DirectionsRoute({
    required this.parkingLotId,
    required this.parkingName,
    required this.origin,
    required this.destination,
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.steps,
  });
}
