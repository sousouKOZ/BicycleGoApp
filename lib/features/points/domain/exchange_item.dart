import 'package:flutter/material.dart';

enum ExchangeCategory { coffee, food, retail, mobility, donation }

extension ExchangeCategoryLabel on ExchangeCategory {
  String get label {
    switch (this) {
      case ExchangeCategory.coffee:
        return 'カフェ';
      case ExchangeCategory.food:
        return 'グルメ';
      case ExchangeCategory.retail:
        return '物販';
      case ExchangeCategory.mobility:
        return 'モビリティ';
      case ExchangeCategory.donation:
        return '寄付';
    }
  }
}

class ExchangeItem {
  final String id;
  final String title;
  final String description;
  final int costPoints;
  final ExchangeCategory category;
  final IconData icon;
  final Color accent;

  const ExchangeItem({
    required this.id,
    required this.title,
    required this.description,
    required this.costPoints,
    required this.category,
    required this.icon,
    required this.accent,
  });
}
