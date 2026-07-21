import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/utils/geo.dart';
import '../../parking/domain/directions_route.dart';
import 'nav_step.dart';

/// ある時点の現在地を経路に突き合わせた結果。
class RouteProgress {
  /// 経路上にスナップした現在地。GPS の揺れを吸収した「経路上の位置」。
  final LatLng snapped;

  /// スナップ地点が乗っているセグメントの始点インデックス。
  final int segmentIndex;

  /// 生の現在地と経路との距離。逸脱判定に使う。
  final double distanceFromRouteMeters;

  final double traveledMeters;
  final double remainingMeters;
  final int remainingSeconds;

  /// 現在走行中の区間。
  final int stepIndex;

  /// 次の曲がり角までの距離。
  final double distanceToManeuverMeters;

  /// 経路の接線方向（進行方向）。カメラの bearing に使う。
  final double courseDegrees;

  const RouteProgress({
    required this.snapped,
    required this.segmentIndex,
    required this.distanceFromRouteMeters,
    required this.traveledMeters,
    required this.remainingMeters,
    required this.remainingSeconds,
    required this.stepIndex,
    required this.distanceToManeuverMeters,
    required this.courseDegrees,
  });

  DateTime get eta => DateTime.now().add(Duration(seconds: remainingSeconds));
}

/// 現在地を経路にスナップして進捗（残距離・残時間・次の曲がり角）を出す。
///
/// 位置ストリームから毎フィックス呼ばれるため、経路の累積距離と平面座標は
/// 生成時に一度だけ前計算しておく。
class RouteTracker {
  final DirectionsRoute route;

  /// path[i] までの累積距離（メートル）。
  final List<double> _cumulative;

  /// path を局所平面（メートル）に落とした座標。緯度経度のままだと
  /// セグメントへの射影が正しく計算できないため。
  final List<_Point> _plane;

  /// 各 step の開始距離（経路始点からの累積距離）。
  final List<double> _stepStartMeters;

  final double _refLat;
  final double _refLng;

  /// 前回スナップしたセグメント。折り返しや近接する往復路で経路上の
  /// 遠い地点に誤ってスナップしないよう、次回はこの近傍から探す。
  int _lastSegment = 0;

  RouteTracker(this.route)
      : assert(route.polyline.length >= 2),
        _cumulative = _buildCumulative(route.polyline),
        _refLat = route.polyline.first.latitude,
        _refLng = route.polyline.first.longitude,
        _plane = _buildPlane(route.polyline),
        _stepStartMeters = <double>[] {
    for (final step in route.steps) {
      final index = step.pathStartIndex.clamp(0, _cumulative.length - 1);
      _stepStartMeters.add(_cumulative[index]);
    }
  }

  double get totalMeters => _cumulative.last;

  static List<double> _buildCumulative(List<LatLng> path) {
    final cumulative = <double>[0];
    for (var i = 1; i < path.length; i++) {
      cumulative.add(
        cumulative[i - 1] + Geo.haversineMeters(path[i - 1], path[i]),
      );
    }
    return cumulative;
  }

  static List<_Point> _buildPlane(List<LatLng> path) {
    final refLat = path.first.latitude;
    final refLng = path.first.longitude;
    return [
      for (final p in path) _project(p, refLat, refLng),
    ];
  }

  static const double _metersPerDegreeLat = 111320.0;

  static _Point _project(LatLng p, double refLat, double refLng) {
    final metersPerDegreeLng =
        _metersPerDegreeLat * math.cos(refLat * math.pi / 180.0);
    return _Point(
      (p.longitude - refLng) * metersPerDegreeLng,
      (p.latitude - refLat) * _metersPerDegreeLat,
    );
  }

  LatLng _unproject(_Point p) {
    final metersPerDegreeLng =
        _metersPerDegreeLat * math.cos(_refLat * math.pi / 180.0);
    return LatLng(
      _refLat + p.y / _metersPerDegreeLat,
      _refLng + p.x / metersPerDegreeLng,
    );
  }

  /// 現在地を経路に突き合わせる。
  RouteProgress locate(LatLng position) {
    final here = _project(position, _refLat, _refLng);

    // 直近セグメントの周辺だけを探す。ここで見つからない（＝大きく外れた）
    // 場合のみ経路全体を探し直す。GPS の飛びやアプリ復帰後にも追従できる。
    var best = _search(here, _lastSegment - 8, _lastSegment + 80);
    if (best.distance > _rematchThresholdMeters) {
      final full = _search(here, 0, _plane.length - 2);
      if (full.distance < best.distance) best = full;
    }
    _lastSegment = best.segment;

    final traveled = (_cumulative[best.segment] + best.alongSegment)
        .clamp(0.0, totalMeters);
    final remaining = (totalMeters - traveled).clamp(0.0, totalMeters);
    final stepIndex = _stepIndexAt(traveled);

    return RouteProgress(
      snapped: _unproject(best.point),
      segmentIndex: best.segment,
      distanceFromRouteMeters: best.distance,
      traveledMeters: traveled,
      remainingMeters: remaining,
      remainingSeconds: _remainingSeconds(traveled, stepIndex),
      stepIndex: stepIndex,
      distanceToManeuverMeters:
          (_stepEndMeters(stepIndex) - traveled).clamp(0.0, totalMeters),
      courseDegrees: _courseAt(best.segment),
    );
  }

  /// 経路全体を探し直す距離のしきい値。逸脱しきい値より大きく取り、
  /// 「少し外れた」だけで全探索が走らないようにする。
  static const double _rematchThresholdMeters = 60.0;

  _Match _search(_Point here, int from, int to) {
    final start = from.clamp(0, _plane.length - 2);
    final end = to.clamp(0, _plane.length - 2);
    var best = const _Match(segment: 0, distance: double.infinity,
        alongSegment: 0, point: _Point(0, 0));
    for (var i = start; i <= end; i++) {
      final a = _plane[i];
      final b = _plane[i + 1];
      final dx = b.x - a.x;
      final dy = b.y - a.y;
      final lengthSq = dx * dx + dy * dy;
      // 射影パラメータ t（0=始点, 1=終点）。長さ 0 のセグメントは始点に潰す。
      final t = lengthSq == 0
          ? 0.0
          : (((here.x - a.x) * dx + (here.y - a.y) * dy) / lengthSq)
              .clamp(0.0, 1.0);
      final projected = _Point(a.x + dx * t, a.y + dy * t);
      final distance = math.sqrt(
        math.pow(here.x - projected.x, 2) + math.pow(here.y - projected.y, 2),
      );
      if (distance < best.distance) {
        best = _Match(
          segment: i,
          distance: distance,
          alongSegment: math.sqrt(lengthSq) * t,
          point: projected,
        );
      }
    }
    return best;
  }

  int _stepIndexAt(double traveled) {
    if (_stepStartMeters.isEmpty) return 0;
    var index = 0;
    for (var i = 0; i < _stepStartMeters.length; i++) {
      // 区間の始点ちょうどでは「その区間に入った」とみなす。
      if (traveled + 0.5 >= _stepStartMeters[i]) index = i;
    }
    return index;
  }

  /// [stepIndex] の区間が終わる（＝曲がり角に到達する）累積距離。
  double _stepEndMeters(int stepIndex) {
    final next = stepIndex + 1;
    if (next < _stepStartMeters.length) return _stepStartMeters[next];
    return totalMeters;
  }

  /// 残り時間は「現区間の残り比率 × 現区間の所要時間 + 以降の区間の所要時間」。
  /// 全体距離の按分より、信号や坂で区間ごとに速度が違う経路に強い。
  int _remainingSeconds(double traveled, int stepIndex) {
    if (route.steps.isEmpty) {
      final ratio = totalMeters == 0 ? 0.0 : (totalMeters - traveled) / totalMeters;
      return (route.durationSeconds * ratio).round();
    }
    final step = route.steps[stepIndex];
    final stepStart = _stepStartMeters[stepIndex];
    final stepLength = _stepEndMeters(stepIndex) - stepStart;
    final stepRemaining = (_stepEndMeters(stepIndex) - traveled).clamp(0.0, stepLength);
    final stepRatio = stepLength <= 0 ? 0.0 : stepRemaining / stepLength;

    var seconds = step.durationSeconds * stepRatio;
    for (var i = stepIndex + 1; i < route.steps.length; i++) {
      seconds += route.steps[i].durationSeconds;
    }
    return seconds.round();
  }

  double _courseAt(int segment) {
    final i = segment.clamp(0, route.polyline.length - 2);
    return Geo.bearingDegrees(route.polyline[i], route.polyline[i + 1]);
  }

  NavStep? stepAt(int index) =>
      index >= 0 && index < route.steps.length ? route.steps[index] : null;
}

class _Point {
  final double x;
  final double y;
  const _Point(this.x, this.y);
}

class _Match {
  final int segment;
  final double distance;
  final double alongSegment;
  final _Point point;
  const _Match({
    required this.segment,
    required this.distance,
    required this.alongSegment,
    required this.point,
  });
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
