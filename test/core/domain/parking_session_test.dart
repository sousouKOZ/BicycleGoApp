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

  group('ParkingSession.authDeadline', () {
    test('検知時刻 + 認証猶予(authGrace)', () {
      final s = build();
      expect(s.authDeadline, detectedAt.add(ParkingSession.authGrace));
    });

    test('authGrace は 5 分', () {
      expect(ParkingSession.authGrace, const Duration(minutes: 5));
    });
  });

  group('ParkingSession.earnDeadline', () {
    test('未認証なら null', () {
      final s = build();
      expect(s.earnDeadline, isNull);
    });

    test('認証済みなら 認証時刻 + 発行しきい値(earnThreshold)', () {
      final authAt = detectedAt.add(const Duration(minutes: 2));
      final s = build(authenticatedAt: authAt);
      expect(s.earnDeadline, authAt.add(ParkingSession.earnThreshold));
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
      // 認証時刻を入れたので earnDeadline が算出される
      expect(updated.earnDeadline, authAt.add(ParkingSession.earnThreshold));
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
