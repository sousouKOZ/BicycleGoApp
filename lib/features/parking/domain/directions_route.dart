import 'package:google_maps_flutter/google_maps_flutter.dart';

class DirectionsRoute {
  final String parkingLotId;
  final String parkingName;
  final LatLng origin;
  final LatLng destination;
  final List<LatLng> polyline;
  final int distanceMeters;
  final int durationSeconds;

  const DirectionsRoute({
    required this.parkingLotId,
    required this.parkingName,
    required this.origin,
    required this.destination,
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
  });
}
