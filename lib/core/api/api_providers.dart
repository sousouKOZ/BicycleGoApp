import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/api_config.dart';
import 'api_client.dart';
import 'mock_api_client.dart';
import 'supabase_api_client.dart';

/// ApiClient の DI ポイント。
///
/// `--dart-define=USE_SUPABASE=true` で起動するとローカル/本番 Supabase に接続、
/// 未指定なら MockApiClient（オフライン UI 開発用）。
final apiClientProvider = Provider<ApiClient>((ref) {
  if (useSupabase) {
    return SupabaseApiClient(Supabase.instance.client);
  }
  return MockApiClient();
});
