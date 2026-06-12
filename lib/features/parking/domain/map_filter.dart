/// 地図マーカーの絞り込み条件。
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
