import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/domain/parking_lot.dart';

final parkingLotsProvider = FutureProvider<List<ParkingLot>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getParkingLots();
});

final parkingSearchQueryProvider = StateProvider<String>((ref) => '');

final currentLocationProvider = StateProvider<LatLng?>((ref) => null);

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
