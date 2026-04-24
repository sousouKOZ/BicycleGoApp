/// 完了したセッションの履歴エントリ。端末ローカルに永続化される。
class SessionRecord {
  final String id;
  final String parkingId;
  final String parkingName;
  final DateTime startedAt;
  final DateTime completedAt;
  final int earnedPoints;
  final String? issuedCouponId;
  final String? couponBenefit;

  const SessionRecord({
    required this.id,
    required this.parkingId,
    required this.parkingName,
    required this.startedAt,
    required this.completedAt,
    required this.earnedPoints,
    this.issuedCouponId,
    this.couponBenefit,
  });

  Duration get duration => completedAt.difference(startedAt);

  Map<String, Object?> toJson() => {
        'id': id,
        'parkingId': parkingId,
        'parkingName': parkingName,
        'startedAt': startedAt.toIso8601String(),
        'completedAt': completedAt.toIso8601String(),
        'earnedPoints': earnedPoints,
        'issuedCouponId': issuedCouponId,
        'couponBenefit': couponBenefit,
      };

  factory SessionRecord.fromJson(Map<String, Object?> j) {
    return SessionRecord(
      id: j['id'] as String,
      parkingId: j['parkingId'] as String,
      parkingName: j['parkingName'] as String,
      startedAt: DateTime.parse(j['startedAt'] as String),
      completedAt: DateTime.parse(j['completedAt'] as String),
      earnedPoints: (j['earnedPoints'] as num).toInt(),
      issuedCouponId: j['issuedCouponId'] as String?,
      couponBenefit: j['couponBenefit'] as String?,
    );
  }
}
