import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Firebase Cloud Messaging のセットアップを集約するシングルトン。
///
/// Firebase 設定（Android: `android/app/google-services.json`）が
/// 配置されていない開発環境では `init()` は黙って失敗し、`isAvailable`
/// は false のまま。アプリ起動は継続する。
class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  bool _initialized = false;
  bool get isAvailable => _initialized;

  /// アプリ起動時に1回だけ呼ぶ。Firebase の初期化、通知権限、トークン取得、
  /// 受信ハンドラ登録までを行う。
  Future<void> init() async {
    if (_initialized) return;
    try {
      await Firebase.initializeApp();

      // Android 13+ は通知権限が必要。permissionGranted は将来の Settings 画面で参照可能。
      await FirebaseMessaging.instance.requestPermission();

      // フォアグラウンドで受信した通知はサーバ自律発行を契機にした再 fetch のみに使う。
      // 画面遷移は Realtime 経路が担当するので、ここでは何もしない（ログのみ）。
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('[FCM] foreground: ${message.data}');
      });

      // バックグラウンド状態で通知をタップして起動した場合：
      // home_shell が AppLifecycle resume で _restoreFromServer を再実行し、
      // achieved セッションがあれば祝福画面を出す。ここでは記録のみ。
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('[FCM] tapped: ${message.data}');
      });

      _initialized = true;
    } catch (e) {
      debugPrint('[FCM] init skipped (Firebase 未設定?): $e');
    }
  }

  /// FCM トークンを `users.fcm_token` に upsert する。
  /// サインイン直後に1回、トークン更新時にもう1回呼ばれる想定。
  Future<void> registerToken({required String userId}) async {
    if (!_initialized) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _saveToken(userId: userId, token: token);
      }
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _saveToken(userId: userId, token: newToken);
      });
    } catch (e) {
      debugPrint('[FCM] registerToken failed: $e');
    }
  }

  Future<void> _saveToken({
    required String userId,
    required String token,
  }) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'fcm_token': token}).eq('id', userId);
    } catch (e) {
      debugPrint('[FCM] saveToken failed: $e');
    }
  }
}
