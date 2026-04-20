import 'package:google_maps_flutter/google_maps_flutter.dart';

enum StoreCategory { cafe, restaurant, bakery, retail, sweets, bar }

extension StoreCategoryLabel on StoreCategory {
  String get label {
    switch (this) {
      case StoreCategory.cafe:
        return 'カフェ';
      case StoreCategory.restaurant:
        return '飲食';
      case StoreCategory.bakery:
        return 'ベーカリー';
      case StoreCategory.retail:
        return '物販';
      case StoreCategory.sweets:
        return 'スイーツ';
      case StoreCategory.bar:
        return 'バー';
    }
  }
}

class Store {
  final String id;
  final String name;
  final StoreCategory category;
  final LatLng position;
  final String benefit;
  final double recommendWeight;

  const Store({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
    required this.benefit,
    required this.recommendWeight,
  });
}
