import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 地図マーカーのフィルタ状態。画面横断で共有するのでStateProvider。
class MapFilter {
  final bool availableOnly;
  final bool couponOnly;
  final bool favoriteOnly;
  final bool within15MinutesOnly;

  const MapFilter({
    this.availableOnly = false,
    this.couponOnly = false,
    this.favoriteOnly = false,
    this.within15MinutesOnly = false,
  });

  bool get hasAny =>
      availableOnly || couponOnly || favoriteOnly || within15MinutesOnly;

  MapFilter copyWith({
    bool? availableOnly,
    bool? couponOnly,
    bool? favoriteOnly,
    bool? within15MinutesOnly,
  }) {
    return MapFilter(
      availableOnly: availableOnly ?? this.availableOnly,
      couponOnly: couponOnly ?? this.couponOnly,
      favoriteOnly: favoriteOnly ?? this.favoriteOnly,
      within15MinutesOnly: within15MinutesOnly ?? this.within15MinutesOnly,
    );
  }
}

final mapFilterProvider = StateProvider<MapFilter>((_) => const MapFilter());
