enum ParkingSessionStatus {
  unauthenticated,
  measuring,
  achieved,
  // クーポン獲得後も自転車をまだ出していない状態。
  // ユーザーが「自転車を出す」操作を行うまで保持される。
  parked,
  // achieved/parked からの正常出庫（クーポン獲得済み）。
  completed,
  // 15分達成前にユーザーがアプリで能動的に計測を中止した（クーポン未発行）。
  // 猶予切れ/センサー出庫の expired とは区別する。
  cancelled,
  expired;

  /// DB の文字列表現（enum 名と同一）から変換する。未知の値は null。
  static ParkingSessionStatus? fromDb(String s) {
    for (final v in values) {
      if (v.name == s) return v;
    }
    return null;
  }
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

  /// 撮影モード判定（UI 表示・通知タイミング計算に使う）。
  static bool get isDemoMode => _isDemoMode;

  /// 経過時間計算の起点。
  /// デモ時はローカル時計で作った detectedAt を使い時計ズレを防止。
  /// 実機（本番）時はサーバーが記録した authenticatedAt を正しく使う。
  /// 未認証の本番セッションでは null。
  DateTime? get elapsedBasis => _isDemoMode ? detectedAt : authenticatedAt;

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

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
