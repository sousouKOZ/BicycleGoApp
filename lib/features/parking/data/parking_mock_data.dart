import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../domain/parking_lot.dart';

final mockParkingLots = <ParkingLot>[
  ParkingLot(
    id: 'p1',
    name: '梅田 駐輪場',
    position: const LatLng(34.7025, 135.4959),
    capacity: 50,
    occupied: 40,
    priceYenPerDay: 150,
    updatedAt: DateTime.now(),
  ),
  ParkingLot(
    id: 'p2',
    name: '中崎町 駐輪場',
    position: const LatLng(34.7072, 135.5050),
    capacity: 30,
    occupied: 10,
    priceYenPerDay: 100,
    updatedAt: DateTime.now(),
  ),
  ParkingLot(
    id: 'p3',
    name: '扇町 駐輪場',
    position: const LatLng(34.7050, 135.5120),
    capacity: 40,
    occupied: 35,
    priceYenPerDay: 200,
    updatedAt: DateTime.now(),
  ),
  ParkingLot(
    id: 'p4',
    name: '天神橋筋 駐輪場',
    position: const LatLng(34.7078, 135.5134),
    capacity: 60,
    occupied: 20,
    priceYenPerDay: 120,
    updatedAt: DateTime.now(),
  ),
];
