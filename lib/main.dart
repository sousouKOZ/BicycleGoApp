import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/api_config.dart';
import 'core/notifications/fcm_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // FCM は Firebase 未設定の環境では init が黙って no-op になる。
  await FcmService.instance.init();

  // Supabase 初期化。未サインインなら Anonymous Sign-In で auth.users 行を確保。
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'SUPABASE_URL / SUPABASE_ANON_KEY が未設定です。'
      'env/dev.json または env/prod.json を確認してください。',
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
      debugPrint('anonymous sign-in failed: $e');
    }
  }
  final userId = auth.currentUser?.id;
  if (userId != null) {
    // FCM トークンを users.fcm_token に保存。Firebase 未設定なら no-op。
    unawaited(FcmService.instance.registerToken(userId: userId));
  }

  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
