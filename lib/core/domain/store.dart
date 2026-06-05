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
  
  // Python APIから付与される動的レコメンド情報
  final String? recommendReason;
  final double? finalScore;

  const Store({
    required this.id,
    required this.name,
    required this.category,
    required this.position,
    required this.benefit,
    required this.recommendWeight,
    this.recommendReason,
    this.finalScore,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    StoreCategory parseCategory(String cat) {
      switch (cat.toLowerCase()) {
        case 'cafe': return StoreCategory.cafe;
        case 'bakery': return StoreCategory.bakery;
        case 'sweets': return StoreCategory.sweets;
        case 'bar': return StoreCategory.bar;
        case 'retail': return StoreCategory.retail;
        default: return StoreCategory.restaurant;
      }
    }

    return Store(
      id: json['id'] as String,
      name: json['name'] as String,
      category: parseCategory(json['category'] as String),
      position: LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble()),
      benefit: json['benefit'] as String,
      recommendWeight: (json['recommend_weight'] as num?)?.toDouble() ?? 0.5,
      recommendReason: json['recommend_reason'] as String?,
      finalScore: (json['final_score'] as num?)?.toDouble(),
    );
  }
}
