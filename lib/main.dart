import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/api_config.dart';
import 'features/sessions/data/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();

  // USE_SUPABASE=true で起動した時のみ Supabase を初期化。
  // 初期化後、未サインインなら Anonymous Sign-In で auth.users 行を確保。
  if (useSupabase) {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'USE_SUPABASE=true ですが SUPABASE_URL / SUPABASE_ANON_KEY が未設定です。'
        'env/dev.json を確認してください。',
      );
    }
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
    final auth = Supabase.instance.client.auth;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        // 失敗しても起動は続行（後続の API 呼び出しが unauthorized で失敗するのみ）
        debugPrint('anonymous sign-in failed: $e');
      }
    }
  }

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}
