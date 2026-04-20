import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../domain/store.dart';

final mockStores = <Store>[
  Store(
    id: 's1',
    name: 'カフェ 梅田コーヒー',
    category: StoreCategory.cafe,
    position: const LatLng(34.7028, 135.4968),
    benefit: 'ドリンク 100円OFF',
    recommendWeight: 0.9,
  ),
  Store(
    id: 's2',
    name: '中崎町ベーカリー',
    category: StoreCategory.bakery,
    position: const LatLng(34.7075, 135.5048),
    benefit: 'パン 1個サービス',
    recommendWeight: 0.8,
  ),
  Store(
    id: 's3',
    name: '扇町食堂',
    category: StoreCategory.restaurant,
    position: const LatLng(34.7055, 135.5125),
    benefit: 'ランチ 200円OFF',
    recommendWeight: 0.7,
  ),
  Store(
    id: 's4',
    name: '天神橋スイーツ',
    category: StoreCategory.sweets,
    position: const LatLng(34.7080, 135.5140),
    benefit: 'ケーキ 10%OFF',
    recommendWeight: 0.85,
  ),
  Store(
    id: 's5',
    name: '梅田バル',
    category: StoreCategory.bar,
    position: const LatLng(34.7031, 135.4975),
    benefit: '1ドリンク無料',
    recommendWeight: 0.6,
  ),
];
