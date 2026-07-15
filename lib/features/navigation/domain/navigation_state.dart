import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/domain/parking_lot.dart';
import '../../parking/domain/directions_route.dart';
import 'nav_step.dart';
import 'route_tracker.dart';

enum NavPhase {
  /// 位置ストリームからの最初のフィックス待ち。
  locating,

  /// 通常の案内中。
  guiding,

  /// 経路を外れてリルート取得中。
  rerouting,

  /// 経路を外れているがリルートに失敗した（再試行待ち）。
  offRoute,

  /// 目的地に到着。位置の追従は止めている。
  arrived,
}

class NavigationState {
  final ParkingLot parking;
  final DirectionsRoute route;
  final NavPhase phase;

  /// 最新のフィックスを経路に突き合わせた結果。[NavPhase.locating] の間は null。
  final RouteProgress? progress;

  /// 生の現在地（スナップ前）。
  final LatLng? rawPosition;

  /// 端末の進行方向（GPS heading）。停止中は不定なので null。
  final double? headingDegrees;

  /// リルート失敗などの一時的なエラー。案内自体は継続する。
  final String? error;

  const NavigationState({
    required this.parking,
    required this.route,
    required this.phase,
    this.progress,
    this.rawPosition,
    this.headingDegrees,
    this.error,
  });

  /// 走行中の区間。
  NavStep? get currentStep {
    final index = progress?.stepIndex;
    if (index == null || index >= route.steps.length) return null;
    return route.steps[index];
  }

  /// 次にとる操作。Directions API の maneuver は「その区間の開始時の操作」なので、
  /// 走行中の区間の“次”の区間が、次の曲がり角の指示になる。
  /// 最終区間を走行中なら null（＝次は到着）。
  NavStep? get upcomingStep => _stepAt((progress?.stepIndex ?? -1) + 1);

  /// さらにその次の操作（「その先、左折」のプレビュー用）。
  NavStep? get followingStep => _stepAt((progress?.stepIndex ?? -1) + 2);

  NavStep? _stepAt(int index) =>
      index >= 0 && index < route.steps.length ? route.steps[index] : null;

  /// 次の曲がり角の指示文。到着が次なら到着案内。
  String get upcomingInstruction =>
      upcomingStep?.instruction ?? '${parking.name} に到着します';

  NavManeuver get upcomingManeuver =>
      upcomingStep?.maneuver ?? NavManeuver.arrive;

  double get distanceToManeuverMeters =>
      progress?.distanceToManeuverMeters ?? 0;

  double get remainingMeters =>
      progress?.remainingMeters ?? route.distanceMeters.toDouble();

  int get remainingSeconds =>
      progress?.remainingSeconds ?? route.durationSeconds;

  DateTime get eta => DateTime.now().add(Duration(seconds: remainingSeconds));

  bool get isOffRoute =>
      phase == NavPhase.rerouting || phase == NavPhase.offRoute;

  NavigationState copyWith({
    ParkingLot? parking,
    DirectionsRoute? route,
    NavPhase? phase,
    RouteProgress? progress,
    LatLng? rawPosition,
    double? headingDegrees,
    String? error,
    bool clearError = false,
  }) {
    return NavigationState(
      parking: parking ?? this.parking,
      route: route ?? this.route,
      phase: phase ?? this.phase,
      progress: progress ?? this.progress,
      rawPosition: rawPosition ?? this.rawPosition,
      headingDegrees: headingDegrees ?? this.headingDegrees,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
