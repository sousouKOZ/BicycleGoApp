import 'package:bicycle_go/core/domain/parking_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final detectedAt = DateTime.utc(2026, 6, 1, 10, 0, 0);

  ParkingSession build({
    DateTime? authenticatedAt,
    ParkingSessionStatus status = ParkingSessionStatus.measuring,
  }) {
    return ParkingSession(
      id: 'sess-1',
      deviceId: 'dev-1',
      detectedAt: detectedAt,
      status: status,
      authenticatedAt: authenticatedAt,
    );
  }

  group('ParkingSession 定数', () {
    test('authGrace は 5 分', () {
      expect(ParkingSession.authGrace, const Duration(minutes: 5));
    });

    test('earnThreshold は通常ビルドで 15 分', () {
      expect(ParkingSession.earnThreshold, const Duration(minutes: 15));
    });
  });

  group('ParkingSession.elapsedBasis（タイマ経過の起点／No.41）', () {
    test('通常ビルドでは認証時刻(authenticatedAt)を起点にする', () {
      final authAt = detectedAt.add(const Duration(minutes: 1));
      final s = build(authenticatedAt: authAt);
      expect(s.elapsedBasis, authAt);
    });

    test('未認証（authenticatedAt=null）では起点が無い', () {
      final s = build();
      expect(s.elapsedBasis, isNull);
    });

    test('通常ビルドは撮影用デモモードではない', () {
      // DEMO 未指定でビルドした場合、15分しきい値・本番起点が選ばれること。
      expect(ParkingSession.isDemoMode, isFalse);
    });
  });

  group('ParkingSession.copyWith', () {
    test('不変フィールド(id/deviceId/detectedAt)は保持する', () {
      final s = build();
      final updated = s.copyWith(status: ParkingSessionStatus.achieved);
      expect(updated.id, s.id);
      expect(updated.deviceId, s.deviceId);
      expect(updated.detectedAt, s.detectedAt);
    });

    test('指定したフィールドのみ更新する', () {
      final s = build();
      final authAt = detectedAt.add(const Duration(minutes: 1));
      final updated = s.copyWith(
        status: ParkingSessionStatus.achieved,
        authenticatedAt: authAt,
        issuedCouponId: 'cp-1',
      );
      expect(updated.status, ParkingSessionStatus.achieved);
      expect(updated.authenticatedAt, authAt);
      expect(updated.issuedCouponId, 'cp-1');
    });

    test('引数省略時は元の値を維持する', () {
      final authAt = detectedAt.add(const Duration(minutes: 1));
      final s = build(
        authenticatedAt: authAt,
        status: ParkingSessionStatus.achieved,
      );
      final copy = s.copyWith();
      expect(copy.status, ParkingSessionStatus.achieved);
      expect(copy.authenticatedAt, authAt);
    });
  });
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
