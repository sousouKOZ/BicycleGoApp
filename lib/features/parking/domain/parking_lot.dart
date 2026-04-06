import 'package:google_maps_flutter/google_maps_flutter.dart';

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
}
