import 'package:flutter_riverpod/flutter_riverpod.dart';

const int defaultPoints = 120;

final pointsProvider = StateProvider<int>((ref) => defaultPoints);
