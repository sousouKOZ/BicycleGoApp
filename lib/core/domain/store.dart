import 'package:google_maps_flutter/google_maps_flutter.dart';

enum StoreCategory {
  cafe,
  restaurant,
  bakery,
  retail,
  sweets,
  bar;

  /// DB の文字列表現（enum 名と同一）から変換する。未知の値は null。
  static StoreCategory? fromDb(String s) {
    for (final v in values) {
      if (v.name == s) return v;
    }
    return null;
  }
}

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
    return Store(
      id: json['id'] as String,
      name: json['name'] as String,
      // レコメンド API 由来のデータは未知カテゴリを restaurant に倒す。
      category:
          StoreCategory.fromDb((json['category'] as String).toLowerCase()) ??
              StoreCategory.restaurant,
      position: LatLng((json['lat'] as num).toDouble(), (json['lng'] as num).toDouble()),
      benefit: json['benefit'] as String,
      recommendWeight: (json['recommend_weight'] as num?)?.toDouble() ?? 0.5,
      recommendReason: json['recommend_reason'] as String?,
      finalScore: (json['final_score'] as num?)?.toDouble(),
    );
  }
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
