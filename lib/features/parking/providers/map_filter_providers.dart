import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/map_filter.dart';

export '../domain/map_filter.dart';

/// 地図マーカーのフィルタ状態。画面横断で共有するのでStateProvider。
final mapFilterProvider = StateProvider<MapFilter>((_) => const MapFilter());

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
