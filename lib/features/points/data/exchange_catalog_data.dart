import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/exchange_item.dart';

const List<ExchangeItem> exchangeCatalog = [
  ExchangeItem(
    id: 'item-coffee-100',
    title: 'コーヒー1杯無料券',
    description: '提携カフェでドリップコーヒー1杯と交換。',
    costPoints: 100,
    category: ExchangeCategory.coffee,
    icon: Icons.coffee_rounded,
    accent: AppColors.accent,
  ),
  ExchangeItem(
    id: 'item-bakery-150',
    title: 'パン1つ無料券',
    description: '提携ベーカリーで好きなパン1つと交換。',
    costPoints: 150,
    category: ExchangeCategory.food,
    icon: Icons.bakery_dining_rounded,
    accent: AppColors.warning,
  ),
  ExchangeItem(
    id: 'item-lunch-300',
    title: 'ランチ¥500割引',
    description: '提携レストランのランチタイム500円OFF。',
    costPoints: 300,
    category: ExchangeCategory.food,
    icon: Icons.restaurant_rounded,
    accent: AppColors.accentAlt,
  ),
  ExchangeItem(
    id: 'item-retail-200',
    title: '雑貨¥300クーポン',
    description: '提携セレクトショップで300円OFFクーポンを発行。',
    costPoints: 200,
    category: ExchangeCategory.retail,
    icon: Icons.shopping_bag_rounded,
    accent: AppColors.accent,
  ),
  ExchangeItem(
    id: 'item-mobility-500',
    title: 'シェアサイクル30分無料',
    description: '提携シェアサイクルの30分利用券。',
    costPoints: 500,
    category: ExchangeCategory.mobility,
    icon: Icons.pedal_bike_rounded,
    accent: AppColors.success,
  ),
  ExchangeItem(
    id: 'item-donation-100',
    title: '街の自転車駐輪場 整備に寄付',
    description: '集まったポイントは大阪市の駐輪場整備に活用されます。',
    costPoints: 100,
    category: ExchangeCategory.donation,
    icon: Icons.favorite_rounded,
    accent: AppColors.danger,
  ),
];
