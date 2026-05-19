import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';
import 'supabase_api_client.dart';

/// ApiClient の DI ポイント。常に本番/ローカル Supabase に接続する。
final apiClientProvider = Provider<ApiClient>((ref) {
  return SupabaseApiClient(Supabase.instance.client);
});
