import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../domain/directions_route.dart';
import '../domain/parking_lot.dart';

class DirectionsException implements Exception {
  final String message;
  DirectionsException(this.message);
  @override
  String toString() => 'DirectionsException: $message';
}

class DirectionsService {
  static const _endpoint =
      'https://maps.googleapis.com/maps/api/directions/json';

  Future<DirectionsRoute> fetch({
    required LatLng origin,
    required ParkingLot parking,
    String mode = 'bicycling',
  }) async {
    if (directionsApiKey.isEmpty) {
      throw DirectionsException(
        'GOOGLE_DIRECTIONS_API_KEY が設定されていません。'
        '--dart-define-from-file=env/dev.json を指定して起動してください。',
      );
    }

    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'origin': '${origin.latitude},${origin.longitude}',
      'destination':
          '${parking.position.latitude},${parking.position.longitude}',
      'mode': mode,
      'language': 'ja',
      'key': directionsApiKey,
    });

    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw DirectionsException('HTTP ${resp.statusCode}');
    }
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final status = body['status'] as String? ?? 'UNKNOWN_ERROR';
    if (status != 'OK') {
      final err = body['error_message'] as String? ?? status;
      throw DirectionsException(err);
    }
    final routes = body['routes'] as List<dynamic>;
    if (routes.isEmpty) {
      throw DirectionsException('ルートが見つかりませんでした');
    }
    final route = routes.first as Map<String, dynamic>;
    final overview = route['overview_polyline'] as Map<String, dynamic>;
    final encoded = overview['points'] as String;
    final legs = route['legs'] as List<dynamic>;
    final leg = legs.first as Map<String, dynamic>;
    final distance = (leg['distance'] as Map<String, dynamic>)['value'] as int;
    final duration = (leg['duration'] as Map<String, dynamic>)['value'] as int;

    return DirectionsRoute(
      parkingLotId: parking.id,
      parkingName: parking.name,
      origin: origin,
      destination: parking.position,
      polyline: _decodePolyline(encoded),
      distanceMeters: distance,
      durationSeconds: duration,
    );
  }

  /// Google Encoded Polyline Algorithm Format のデコード。
  /// https://developers.google.com/maps/documentation/utilities/polylinealgorithm
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0;
    int lng = 0;
    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
