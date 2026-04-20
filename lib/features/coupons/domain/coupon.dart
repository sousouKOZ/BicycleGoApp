enum CouponStatus { distributing, owned, used, expired }

enum CouponDistanceTier { near, far, exchange }

extension CouponDistanceTierLabel on CouponDistanceTier {
  String get label {
    switch (this) {
      case CouponDistanceTier.near:
        return '近い';
      case CouponDistanceTier.far:
        return '遠い';
      case CouponDistanceTier.exchange:
        return '交換';
    }
  }
}

class Coupon {
  final String id;
  final String storeId;
  final String storeName;
  final String title;
  final String benefit;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? usedAt;
  final CouponStatus status;
  final CouponDistanceTier distanceTier;

  const Coupon({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.title,
    required this.benefit,
    required this.issuedAt,
    required this.expiresAt,
    required this.status,
    required this.distanceTier,
    this.usedAt,
  });

  bool get isExpired =>
      status == CouponStatus.expired || DateTime.now().isAfter(expiresAt);

  bool get isUsable => status == CouponStatus.owned && !isExpired;

  Coupon copyWith({
    CouponStatus? status,
    DateTime? usedAt,
  }) {
    return Coupon(
      id: id,
      storeId: storeId,
      storeName: storeName,
      title: title,
      benefit: benefit,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      usedAt: usedAt ?? this.usedAt,
      status: status ?? this.status,
      distanceTier: distanceTier,
    );
  }
}
