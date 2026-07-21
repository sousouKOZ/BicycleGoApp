/// 地図マーカーの絞り込み条件。
class MapFilter {
  final bool availableOnly;
  final bool couponOnly;
  final bool favoriteOnly;
  final bool within5MinutesOnly;

  const MapFilter({
    this.availableOnly = false,
    this.couponOnly = false,
    this.favoriteOnly = false,
    this.within5MinutesOnly = false,
  });

  MapFilter copyWith({
    bool? availableOnly,
    bool? couponOnly,
    bool? favoriteOnly,
    bool? within5MinutesOnly,
  }) {
    return MapFilter(
      availableOnly: availableOnly ?? this.availableOnly,
      couponOnly: couponOnly ?? this.couponOnly,
      favoriteOnly: favoriteOnly ?? this.favoriteOnly,
      within5MinutesOnly: within5MinutesOnly ?? this.within5MinutesOnly,
    );
  }
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
