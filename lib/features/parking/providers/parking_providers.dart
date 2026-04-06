import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/parking_repository.dart';
import '../domain/parking_lot.dart';

final parkingRepositoryProvider = Provider<ParkingRepository>((ref) {
  return ParkingRepository();
});

final parkingLotsProvider = FutureProvider<List<ParkingLot>>((ref) async {
  final repo = ref.read(parkingRepositoryProvider);
  return repo.fetchParkingLots();
});

final selectedParkingProvider = StateProvider<ParkingLot?>((ref) => null);

final parkingSearchQueryProvider = StateProvider<String>((ref) => '');

final currentLocationProvider = StateProvider<LatLng?>((ref) => null);
