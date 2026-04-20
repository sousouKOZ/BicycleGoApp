import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'mock_api_client.dart';

/// ApiClient の DI ポイント。HTTPに差し替える場合はここだけ変更する。
final apiClientProvider = Provider<ApiClient>((ref) => MockApiClient());
