enum ParkingSessionStatus {
  unauthenticated,
  measuring,
  achieved,
  // クーポン獲得後も自転車をまだ出していない状態。
  // ユーザーが「自転車を出す」操作を行うまで保持される。
  parked,
  completed,
  expired,
}

class ParkingSession {
  final String id;
  final String deviceId;
  final String? userId;
  final DateTime detectedAt;
  final DateTime? authenticatedAt;
  final DateTime? exitedAt;
  final ParkingSessionStatus status;
  final String? issuedCouponId;

  const ParkingSession({
    required this.id,
    required this.deviceId,
    required this.detectedAt,
    required this.status,
    this.userId,
    this.authenticatedAt,
    this.exitedAt,
    this.issuedCouponId,
  });

  /// `--dart-define=DEMO=true` で起動した時だけ撮影用に短い時間設定を使う。
  /// 通常ビルドでは false なので本番値が選ばれる。
  static const _isDemoMode = bool.fromEnvironment('DEMO');

  static const authGrace = Duration(minutes: 5);
  static const earnThreshold =
      _isDemoMode ? Duration(seconds: 30) : Duration(minutes: 15);
  static const longTermAlert = Duration(hours: 24);

  /// 撮影モード判定（UI 表示・通知タイミング計算に使う）。
  static bool get isDemoMode => _isDemoMode;

  DateTime get authDeadline => detectedAt.add(authGrace);
  DateTime? get earnDeadline => authenticatedAt?.add(earnThreshold);

  ParkingSession copyWith({
    String? userId,
    DateTime? authenticatedAt,
    DateTime? exitedAt,
    ParkingSessionStatus? status,
    String? issuedCouponId,
  }) {
    return ParkingSession(
      id: id,
      deviceId: deviceId,
      detectedAt: detectedAt,
      userId: userId ?? this.userId,
      authenticatedAt: authenticatedAt ?? this.authenticatedAt,
      exitedAt: exitedAt ?? this.exitedAt,
      status: status ?? this.status,
      issuedCouponId: issuedCouponId ?? this.issuedCouponId,
    );
  }
}
