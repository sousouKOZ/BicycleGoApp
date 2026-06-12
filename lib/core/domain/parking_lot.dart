import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 稼働率の段階。UI の配色（マーカー色・バッジ等）はこの段階から導出する。
enum UsageLevel {
  /// 稼働 60% 未満（余裕あり）。
  low,

  /// 稼働 60% 以上 85% 未満（混み始め）。
  mid,

  /// 稼働 85% 以上（ほぼ満車）。
  high,
}

class ParkingLot {
  final String id;
  final String name;
  final LatLng position;
  final int capacity;        // 収容台数
  final int occupied;        // 現在利用台数
  final int priceYenPerDay;  // 料金（プロト用）
  final DateTime updatedAt;

  const ParkingLot({
    required this.id,
    required this.name,
    required this.position,
    required this.capacity,
    required this.occupied,
    required this.priceYenPerDay,
    required this.updatedAt,
  });

  int get available => (capacity - occupied).clamp(0, capacity);

  int get usageRatePercent =>
      capacity == 0 ? 0 : ((occupied / capacity) * 100).round();

  UsageLevel get usageLevel {
    final percent = usageRatePercent;
    if (percent >= 85) return UsageLevel.high;
    if (percent >= 60) return UsageLevel.mid;
    return UsageLevel.low;
  }
}
