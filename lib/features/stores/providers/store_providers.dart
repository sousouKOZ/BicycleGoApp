import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/domain/store.dart';

final storesProvider = FutureProvider<List<Store>>((ref) async {
  final api = ref.watch(apiClientProvider);
  return api.getStores();
});

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
