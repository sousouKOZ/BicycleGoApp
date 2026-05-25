import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/notifications/fcm_service.dart';
import '../../coupons/providers/coupon_providers.dart';
import '../../points/providers/points_providers.dart';
import '../../sessions/providers/session_history_providers.dart';
import '../../user/providers/user_providers.dart';
import 'auth_providers.dart';

/// onAuthStateChange を購読し、認証状態の変化に応じて
///   - ユーザースコープ provider の invalidate
///   - HomeShell 再マウント用 key のバンプ（uid が変わった時のみ）
///   - FCM トークン再登録
/// を行うコントローラ。app.dart で watch してアプリ生存期間維持する。
///
/// 認証アクション（signUp / signIn / 昇格 / signOut / ゲスト継続）も提供。
/// 例外は呼び出し元 UI で catch してメッセージ表示する。
class AuthController {
  AuthController(this._ref) {
    _lastUid = _client.auth.currentUser?.id;
    _sub = _client.auth.onAuthStateChange.listen(_onAuthStateChange);
  }

  final Ref _ref;
  final SupabaseClient _client = Supabase.instance.client;
  late final StreamSubscription<AuthState> _sub;
  String? _lastUid;

  void dispose() {
    _sub.cancel();
  }

  void _onAuthStateChange(AuthState data) {
    switch (data.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.userUpdated:
        _handleAuthenticated();
        break;
      case AuthChangeEvent.signedOut:
        _handleSignedOut();
        break;
      default:
        // tokenRefreshed / initialSession / passwordRecovery 等はゲートを揺らさない。
        break;
    }
  }

  void _handleAuthenticated() {
    final newUid = _client.auth.currentUser?.id;
    // uid が変わった時だけ HomeShell をフル再マウント（Realtime 再購読のため）。
    if (newUid != _lastUid) {
      _lastUid = newUid;
      _ref.read(authSessionKeyProvider.notifier).update((v) => v + 1);
    }
    _invalidateUserScoped();
    if (newUid != null) {
      unawaited(FcmService.instance.registerToken(userId: newUid));
    }
  }

  void _handleSignedOut() {
    _lastUid = null;
    _ref.read(authSessionKeyProvider.notifier).update((v) => v + 1);
    _invalidateUserScoped();
    // ゲスト承認を解除 → AuthLanding に戻す。匿名ユーザーは自動再生成しない。
    unawaited(_ref.read(guestAcknowledgedProvider.notifier).setAcknowledged(false));
  }

  void _invalidateUserScoped() {
    _ref.invalidate(pointsProvider);
    _ref.invalidate(sessionHistoryProvider);
    _ref.invalidate(userCouponsProvider);
    _ref.invalidate(userProfileProvider);
  }

  // ---- 認証アクション ----------------------------------------------------

  /// メール新規登録。匿名ユーザーがいる場合は昇格（uid 不変・データ保持）。
  Future<void> signUpWithEmail(String email, String password) async {
    final user = _client.auth.currentUser;
    if (user != null && user.isAnonymous) {
      await _client.auth.updateUser(
        UserAttributes(email: email, password: password),
      );
    } else {
      await _client.auth.signUp(email: email, password: password);
    }
  }

  /// メールログイン（別アカウントへの切替を含む）。
  Future<void> signInWithEmail(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// ゲストとして利用を続行。匿名ユーザーが無ければ作成し、承認フラグを立てる。
  Future<void> continueAsGuest() async {
    if (_client.auth.currentUser == null) {
      await _client.auth.signInAnonymously();
    }
    await _ref.read(guestAcknowledgedProvider.notifier).setAcknowledged(true);
  }
}

final authControllerProvider = Provider<AuthController>((ref) {
  final controller = AuthController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});
