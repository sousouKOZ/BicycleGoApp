import 'package:flutter_riverpod/flutter_riverpod.dart';

const int defaultPoints = 1000;

final pointsProvider = StateProvider<int>((ref) => defaultPoints);
