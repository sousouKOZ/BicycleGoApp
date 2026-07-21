import 'package:bicycle_go/core/domain/coupon.dart';
import 'package:flutter_test/flutter_test.dart';

/// テスト用の Coupon を生成するヘルパー。
/// 既定は「いま発行され、1時間後に失効する owned クーポン」。
/// 各テストは検証したいフィールドだけ上書きする。
Coupon buildCoupon({
  CouponStatus status = CouponStatus.owned,
  DateTime? expiresAt,
  DateTime? usedAt,
}) {
  final now = DateTime.now();
  return Coupon(
    id: 'cp-test',
    storeId: 'store-1',
    storeName: 'テスト店',
    title: 'テスト特典',
    benefit: '10%OFF',
    issuedAt: now,
    expiresAt: expiresAt ?? now.add(const Duration(hours: 1)),
    status: status,
    distanceTier: CouponDistanceTier.near,
    usedAt: usedAt,
  );
}

void main() {
  group('Coupon.isExpired', () {
    test('owned で有効期限が未来なら未失効', () {
      final c = buildCoupon(expiresAt: DateTime.now().add(const Duration(days: 1)));
      expect(c.isExpired, isFalse);
    });

    test('有効期限を過ぎていれば status に関わらず失効', () {
      final c = buildCoupon(expiresAt: DateTime.now().subtract(const Duration(seconds: 1)));
      expect(c.isExpired, isTrue);
    });

    test('status が expired なら期限が未来でも失効扱い', () {
      final c = buildCoupon(
        status: CouponStatus.expired,
        expiresAt: DateTime.now().add(const Duration(days: 1)),
      );
      expect(c.isExpired, isTrue);
    });
  });

  group('Coupon.isUsable', () {
    test('owned かつ未失効なら使用可能', () {
      final c = buildCoupon(expiresAt: DateTime.now().add(const Duration(days: 1)));
      expect(c.isUsable, isTrue);
    });

    test('used は使用不可', () {
      final c = buildCoupon(status: CouponStatus.used);
      expect(c.isUsable, isFalse);
    });

    test('distributing（配布中・未取得）は使用不可', () {
      final c = buildCoupon(status: CouponStatus.distributing);
      expect(c.isUsable, isFalse);
    });

    test('owned でも期限切れなら使用不可', () {
      final c = buildCoupon(
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(c.isUsable, isFalse);
    });
  });

  group('Coupon.copyWith', () {
    test('status と usedAt を更新し他は保持する', () {
      final original = buildCoupon();
      final usedAt = DateTime(2026, 6, 1, 12);
      final updated = original.copyWith(
        status: CouponStatus.used,
        usedAt: usedAt,
      );

      expect(updated.status, CouponStatus.used);
      expect(updated.usedAt, usedAt);
      // 不変フィールドは元のまま
      expect(updated.id, original.id);
      expect(updated.storeId, original.storeId);
      expect(updated.expiresAt, original.expiresAt);
      expect(updated.distanceTier, original.distanceTier);
    });

    test('引数省略時は元の値を維持する', () {
      final original = buildCoupon(status: CouponStatus.owned);
      final copy = original.copyWith();
      expect(copy.status, original.status);
      expect(copy.usedAt, original.usedAt);
    });
  });
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
