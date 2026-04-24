import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/directions_service.dart';
import '../domain/directions_route.dart';

final directionsServiceProvider = Provider<DirectionsService>(
  (_) => DirectionsService(),
);

/// 現在地図に表示中のルート。null で非表示。
final activeRouteProvider = StateProvider<DirectionsRoute?>((_) => null);

/// ルート取得中のフラグ（UIのローディング表示用）。
final routeLoadingProvider = StateProvider<bool>((_) => false);
