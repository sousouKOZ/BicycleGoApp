import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 地図マーカーのフィルタ状態。画面横断で共有するのでStateProvider。
class MapFilter {
  final bool availableOnly;
  final bool couponOnly;
  final bool favoriteOnly;

  const MapFilter({
    this.availableOnly = false,
    this.couponOnly = false,
    this.favoriteOnly = false,
  });

  bool get hasAny => availableOnly || couponOnly || favoriteOnly;

  MapFilter copyWith({
    bool? availableOnly,
    bool? couponOnly,
    bool? favoriteOnly,
  }) {
    return MapFilter(
      availableOnly: availableOnly ?? this.availableOnly,
      couponOnly: couponOnly ?? this.couponOnly,
      favoriteOnly: favoriteOnly ?? this.favoriteOnly,
    );
  }
}

final mapFilterProvider = StateProvider<MapFilter>((_) => const MapFilter());
