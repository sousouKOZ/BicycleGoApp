import 'package:bicycle_go/features/navigation/domain/nav_step.dart';
import 'package:bicycle_go/features/navigation/domain/route_tracker.dart';
import 'package:bicycle_go/features/parking/domain/directions_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// ターンバイターン案内の土台。現在地を経路に突き合わせて
/// 「どこまで来たか・次の曲がり角まで何 m か・経路を外れたか」を出す部分。
///
/// L 字の経路を使う（東へ約 400m 進み、北へ約 445m 進む）。
/// 緯度 1 度 ≒ 111.2km、経度 1 度 ≒ 91.6km（北緯 34.7 度）で概算。
void main() {
  const origin = LatLng(34.7000, 135.5000);
  const corner = LatLng(34.7000, 135.5040); // origin から東へ約 366m
  const destination = LatLng(34.7040, 135.5040); // corner から北へ約 445m

  DirectionsRoute buildRoute() {
    return const DirectionsRoute(
      parkingLotId: 'lot-1',
      parkingName: 'テスト駐輪場',
      origin: origin,
      destination: destination,
      polyline: [origin, corner, destination],
      distanceMeters: 811,
      durationSeconds: 240,
      steps: [
        NavStep(
          maneuver: NavManeuver.depart,
          instruction: '東に向かって進みます',
          distanceMeters: 366,
          durationSeconds: 108,
          startLocation: origin,
          endLocation: corner,
          pathStartIndex: 0,
        ),
        NavStep(
          maneuver: NavManeuver.turnLeft,
          instruction: '交差点を左折します',
          distanceMeters: 445,
          durationSeconds: 132,
          startLocation: corner,
          endLocation: destination,
          pathStartIndex: 1,
        ),
      ],
    );
  }

  group('RouteTracker.locate', () {
    test('経路上の点は距離 0 でスナップされ、進捗が累積距離になる', () {
      final tracker = RouteTracker(buildRoute());
      // 1本目の区間のちょうど中間（東へ約 183m）。
      final progress = tracker.locate(const LatLng(34.7000, 135.5020));

      expect(progress.distanceFromRouteMeters, closeTo(0, 1));
      expect(progress.traveledMeters, closeTo(183, 5));
      expect(progress.stepIndex, 0);
    });

    test('経路から離れた点は経路上に引き戻され、離れた距離が出る', () {
      final tracker = RouteTracker(buildRoute());
      // 1本目の区間の真横（北へ約 55m ずれた位置）。
      final progress = tracker.locate(const LatLng(34.7005, 135.5020));

      expect(progress.distanceFromRouteMeters, closeTo(55, 5));
      // スナップ先は経路上（＝元の緯度に戻る）。
      expect(progress.snapped.latitude, closeTo(34.7000, 0.0002));
      expect(progress.snapped.longitude, closeTo(135.5020, 0.0002));
    });

    test('次の曲がり角までの距離は現在の区間の残り距離', () {
      final tracker = RouteTracker(buildRoute());
      // 曲がり角の手前 約91m（東へ約 275m 進んだ地点）。
      final progress = tracker.locate(const LatLng(34.7000, 135.5030));

      expect(progress.stepIndex, 0);
      expect(progress.distanceToManeuverMeters, closeTo(91, 6));
    });

    test('曲がり角を過ぎると区間が進み、次の指示は到着になる', () {
      final tracker = RouteTracker(buildRoute());
      // 2本目の区間（北へ約 222m 進んだ地点）。
      final progress = tracker.locate(const LatLng(34.7020, 135.5040));

      expect(progress.stepIndex, 1);
      // 最終区間なので「次の曲がり角」は経路終端＝目的地。
      expect(progress.distanceToManeuverMeters, closeTo(222, 8));
      expect(progress.remainingMeters, closeTo(222, 8));
    });

    test('残り時間は区間ごとの所要時間から積み上げる', () {
      final tracker = RouteTracker(buildRoute());
      // 1本目の中間地点。残り = 1本目の半分(54s) + 2本目の全部(132s)。
      final progress = tracker.locate(const LatLng(34.7000, 135.5020));

      expect(progress.remainingSeconds, closeTo(54 + 132, 6));
    });

    test('進むほど残り距離が減る（進捗が逆行しない）', () {
      final tracker = RouteTracker(buildRoute());
      final early = tracker.locate(const LatLng(34.7000, 135.5010));
      final late = tracker.locate(const LatLng(34.7030, 135.5040));

      expect(late.remainingMeters, lessThan(early.remainingMeters));
      expect(late.traveledMeters, greaterThan(early.traveledMeters));
    });

    test('大きく外れた現在地でも経路全体から最寄りを探し直す', () {
      final tracker = RouteTracker(buildRoute());
      // いったん経路の終盤に進めてから、経路の始点近くへ飛ばす
      // （GPS の飛び・アプリ復帰時に前回位置の近傍しか見ないと追従できなくなる）。
      tracker.locate(const LatLng(34.7035, 135.5040));
      final jumped = tracker.locate(const LatLng(34.7000, 135.5005));

      expect(jumped.stepIndex, 0);
      expect(jumped.traveledMeters, closeTo(46, 8));
      expect(jumped.distanceFromRouteMeters, closeTo(0, 2));
    });
  });
}
