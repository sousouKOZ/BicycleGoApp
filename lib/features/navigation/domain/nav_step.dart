import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Directions API の `steps[].maneuver` に対応する進行指示。
///
/// API は maneuver を省略することがある（直進で案内不要な区間など）。
/// その場合は [straight] に倒す。
enum NavManeuver {
  depart,
  straight,
  turnLeft,
  turnRight,
  turnSlightLeft,
  turnSlightRight,
  turnSharpLeft,
  turnSharpRight,
  uturnLeft,
  uturnRight,
  keepLeft,
  keepRight,
  forkLeft,
  forkRight,
  rampLeft,
  rampRight,
  merge,
  roundaboutLeft,
  roundaboutRight,
  ferry,
  arrive;

  static NavManeuver fromApi(String? raw) {
    switch (raw) {
      case 'turn-left':
        return NavManeuver.turnLeft;
      case 'turn-right':
        return NavManeuver.turnRight;
      case 'turn-slight-left':
        return NavManeuver.turnSlightLeft;
      case 'turn-slight-right':
        return NavManeuver.turnSlightRight;
      case 'turn-sharp-left':
        return NavManeuver.turnSharpLeft;
      case 'turn-sharp-right':
        return NavManeuver.turnSharpRight;
      case 'uturn-left':
        return NavManeuver.uturnLeft;
      case 'uturn-right':
        return NavManeuver.uturnRight;
      case 'keep-left':
        return NavManeuver.keepLeft;
      case 'keep-right':
        return NavManeuver.keepRight;
      case 'fork-left':
        return NavManeuver.forkLeft;
      case 'fork-right':
        return NavManeuver.forkRight;
      case 'ramp-left':
        return NavManeuver.rampLeft;
      case 'ramp-right':
        return NavManeuver.rampRight;
      case 'merge':
        return NavManeuver.merge;
      case 'roundabout-left':
        return NavManeuver.roundaboutLeft;
      case 'roundabout-right':
        return NavManeuver.roundaboutRight;
      case 'ferry':
      case 'ferry-train':
        return NavManeuver.ferry;
      case 'straight':
      default:
        return NavManeuver.straight;
    }
  }

  IconData get icon {
    switch (this) {
      case NavManeuver.depart:
        return Icons.trip_origin_rounded;
      case NavManeuver.straight:
        return Icons.straight_rounded;
      case NavManeuver.turnLeft:
        return Icons.turn_left_rounded;
      case NavManeuver.turnRight:
        return Icons.turn_right_rounded;
      case NavManeuver.turnSlightLeft:
        return Icons.turn_slight_left_rounded;
      case NavManeuver.turnSlightRight:
        return Icons.turn_slight_right_rounded;
      case NavManeuver.turnSharpLeft:
        return Icons.turn_sharp_left_rounded;
      case NavManeuver.turnSharpRight:
        return Icons.turn_sharp_right_rounded;
      case NavManeuver.uturnLeft:
        return Icons.u_turn_left_rounded;
      case NavManeuver.uturnRight:
        return Icons.u_turn_right_rounded;
      case NavManeuver.keepLeft:
      case NavManeuver.forkLeft:
        return Icons.fork_left_rounded;
      case NavManeuver.keepRight:
      case NavManeuver.forkRight:
        return Icons.fork_right_rounded;
      case NavManeuver.rampLeft:
        return Icons.ramp_left_rounded;
      case NavManeuver.rampRight:
        return Icons.ramp_right_rounded;
      case NavManeuver.merge:
        return Icons.merge_rounded;
      case NavManeuver.roundaboutLeft:
        return Icons.roundabout_left_rounded;
      case NavManeuver.roundaboutRight:
        return Icons.roundabout_right_rounded;
      case NavManeuver.ferry:
        return Icons.directions_boat_rounded;
      case NavManeuver.arrive:
        return Icons.sports_score_rounded;
    }
  }
}

/// 経路上の 1 区間。区間の終端に [maneuver]（曲がり角）がある。
class NavStep {
  final NavManeuver maneuver;

  /// 表示・読み上げ両用の日本語指示文。API の html_instructions をプレーン化したもの。
  final String instruction;

  final int distanceMeters;
  final int durationSeconds;
  final LatLng startLocation;
  final LatLng endLocation;

  /// この区間が [DirectionsRoute.polyline] 上のどのインデックスから始まるか。
  /// 進捗（現在どの区間か・次の曲がり角まで何 m か）の算出に使う。
  final int pathStartIndex;

  const NavStep({
    required this.maneuver,
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.startLocation,
    required this.endLocation,
    required this.pathStartIndex,
  });
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
