import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ParkingSortMode { distance, recommend }

final parkingSortModeProvider =
    StateProvider<ParkingSortMode>((_) => ParkingSortMode.distance);

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
