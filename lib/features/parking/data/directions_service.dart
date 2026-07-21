import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../navigation/domain/nav_step.dart';
import '../domain/directions_route.dart';
import '../../../core/domain/parking_lot.dart';

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
      final err = body['error_message'] as String?;
      throw DirectionsException(_friendlyMessage(status, err));
    }
    final routes = body['routes'] as List<dynamic>;
    if (routes.isEmpty) {
      throw DirectionsException('ルートが見つかりませんでした');
    }
    final route = routes.first as Map<String, dynamic>;
    final legs = route['legs'] as List<dynamic>;
    final leg = legs.first as Map<String, dynamic>;
    final distance = (leg['distance'] as Map<String, dynamic>)['value'] as int;
    final duration = (leg['duration'] as Map<String, dynamic>)['value'] as int;

    final path = <LatLng>[];
    final steps = <NavStep>[];
    final rawSteps = (leg['steps'] as List<dynamic>?) ?? const [];
    for (var i = 0; i < rawSteps.length; i++) {
      final raw = rawSteps[i] as Map<String, dynamic>;
      final geometry = _decodePolyline(
        (raw['polyline'] as Map<String, dynamic>)['points'] as String,
      );
      // step の終点と次 step の始点は同一座標。連結時に重複させると
      // 距離 0 のセグメントができてスナップ計算がぶれるので落とす。
      // 重複を落とした場合、この step は「既に入っている最後の点」から始まる。
      final startIndex = path.isEmpty || geometry.isEmpty
          ? path.length
          : _isSamePoint(path.last, geometry.first)
              ? path.length - 1
              : path.length;
      for (final p in geometry) {
        if (path.isNotEmpty && _isSamePoint(path.last, p)) continue;
        path.add(p);
      }

      steps.add(NavStep(
        // 先頭 step の maneuver は API が省略しがちなので出発として扱う。
        maneuver: i == 0 && raw['maneuver'] == null
            ? NavManeuver.depart
            : NavManeuver.fromApi(raw['maneuver'] as String?),
        instruction: _plainInstruction(raw['html_instructions'] as String?),
        distanceMeters:
            (raw['distance'] as Map<String, dynamic>)['value'] as int,
        durationSeconds:
            (raw['duration'] as Map<String, dynamic>)['value'] as int,
        startLocation: _latLng(raw['start_location']),
        endLocation: _latLng(raw['end_location']),
        pathStartIndex: startIndex,
      ));
    }

    if (path.length < 2) {
      throw DirectionsException('ルートの経路情報が取得できませんでした');
    }

    return DirectionsRoute(
      parkingLotId: parking.id,
      parkingName: parking.name,
      origin: origin,
      destination: parking.position,
      polyline: path,
      distanceMeters: distance,
      durationSeconds: duration,
      steps: steps,
    );
  }

  static bool _isSamePoint(LatLng a, LatLng b) =>
      (a.latitude - b.latitude).abs() < 1e-7 &&
      (a.longitude - b.longitude).abs() < 1e-7;

  static LatLng _latLng(dynamic json) {
    final map = json as Map<String, dynamic>;
    return LatLng(
      (map['lat'] as num).toDouble(),
      (map['lng'] as num).toDouble(),
    );
  }

  /// html_instructions（例: `<b>大阪駅前</b>を<b>右</b>に曲がります`）を
  /// 表示・読み上げ用のプレーンテキストに変換する。
  /// 末尾に `<div>` で補足（「目的地は左側です」など）が付くことがあるため、
  /// タグ境界は区切り文字に置き換えてから除去する。
  static String _plainInstruction(String? html) {
    if (html == null || html.isEmpty) return '直進します';
    final withBreaks = html.replaceAll(RegExp(r'</?div[^>]*>'), '\n');
    final stripped = withBreaks.replaceAll(RegExp(r'<[^>]+>'), '');
    final decoded = stripped
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
    final lines = decoded
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return lines.isEmpty ? '直進します' : lines.join(' ');
  }

  /// Directions API の status コードをユーザー向けの文言に変換する。
  /// 切り分けに使えるよう原因の見当も括弧書きで併記。
  String _friendlyMessage(String status, String? errorMessage) {
    switch (status) {
      case 'ZERO_RESULTS':
        return '自転車で行けるルートが見つかりませんでした。'
            '（駐輪場が遠すぎるか、自転車経路が存在しない地域の可能性）';
      case 'MAX_ROUTE_LENGTH_EXCEEDED':
        return 'ルートが長すぎます。'
            '（モックの駐輪場は大阪駅周辺に固定されています。'
            '近くで検証する場合はモックデータを差し替えてください）';
      case 'NOT_FOUND':
        return '出発地または駐輪場の位置を特定できませんでした。';
      case 'REQUEST_DENIED':
        return 'API リクエストが拒否されました。'
            '（GCP Console で Directions API が有効化されているか・'
            'キーの Application restrictions を確認してください）'
            '${errorMessage != null ? "\n詳細: $errorMessage" : ""}';
      case 'OVER_DAILY_LIMIT':
      case 'OVER_QUERY_LIMIT':
        return 'API のクォータ上限を超えました。';
      case 'INVALID_REQUEST':
        return 'リクエストが不正です。$errorMessage';
      case 'UNKNOWN_ERROR':
        return '一時的なサーバエラーです。少し待って再試行してください。';
      default:
        return errorMessage ?? status;
    }
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

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
