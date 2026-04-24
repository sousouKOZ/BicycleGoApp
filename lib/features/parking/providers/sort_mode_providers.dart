import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ParkingSortMode { distance, recommend }

final parkingSortModeProvider =
    StateProvider<ParkingSortMode>((_) => ParkingSortMode.distance);
