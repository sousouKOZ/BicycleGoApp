import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/notifications/fcm_service.dart';
import '../../coupons/providers/coupon_providers.dart';
import '../../parking/providers/favorite_providers.dart';
import '../../parking/providers/recommendation_providers.dart';
import '../../parking/providers/session_providers.dart';
import '../../points/providers/exchange_providers.dart';
import '../../points/providers/points_providers.dart';
import '../../sessions/providers/session_history_providers.dart';
import '../../user/providers/user_providers.dart';
import '../auth_constants.dart';
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

  /// Google OAuth のブラウザ起動中フラグ。ディープリンクで戻った時だけ
  /// push 済み認証ページを畳むために使う。signInWithGoogle でのみ true にし、
  /// 他のすべての認証アクション開始時に false へリセットする。
  /// （ブラウザをキャンセルしてフラグが残ったまま、後続の再認証などで
  ///   _handleAuthenticated が誤って画面を畳むのを防ぐため。）
  bool _awaitingOAuthRedirect = false;

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
      // 別アカウントへ切り替わった瞬間に、前アカウントのアクティブセッションを破棄する。
      // これを怠ると _restoreFromServer が前セッションを掴んだままミニバー等が漏れる。
      // パスワード変更など uid 不変のイベントでは消さない（このブロックに入らない）。
      _resetSessionScoped();
    }
    _invalidateUserScoped();
    if (newUid != null) {
      unawaited(FcmService.instance.registerToken(userId: newUid));
    }
    // Google OAuth はブラウザから非同期にディープリンクで戻るため、その時点で
    // push 済みの認証ページ（ランディング/ログイン/登録）を畳んで背後の
    // HomeShell を表に出す。OAuth 起動時のみフラグを立てるので、再認証や
    // パスワード変更（updateUser）では畳まれない。
    if (_awaitingOAuthRedirect) {
      _awaitingOAuthRedirect = false;
      final nav = rootNavigatorKey.currentState;
      if (nav != null && nav.canPop()) {
        nav.popUntil((route) => route.isFirst);
      }
    }
  }

  void _handleSignedOut() {
    _lastUid = null;
    _ref.read(authSessionKeyProvider.notifier).update((v) => v + 1);
    _invalidateUserScoped();
    _resetSessionScoped();
    // ゲスト承認を解除 → AuthLanding に戻す。匿名ユーザーは自動再生成しない。
    unawaited(_ref.read(guestAcknowledgedProvider.notifier).setAcknowledged(false));
  }

  void _invalidateUserScoped() {
    _ref.invalidate(pointsProvider);
    _ref.invalidate(sessionHistoryProvider);
    _ref.invalidate(userCouponsProvider);
    _ref.invalidate(userProfileProvider);
    // 端末ローカル保存だが uid 別スコープのため、認証切替で再読込が必要。
    _ref.invalidate(exchangeHistoryProvider);
    _ref.invalidate(favoriteParkingsProvider);
  }

  /// アカウント切替・サインアウト時に、前アカウントのアクティブセッション/レコメンドを破棄する。
  /// uid 不変のイベント（パスワード変更・連携）では呼ばない（駐輪中バーを消さないため）。
  void _resetSessionScoped() {
    _ref.invalidate(activeSessionProvider);
    _ref.invalidate(activeParkingInfoProvider);
    _ref.invalidate(recommendedStoresProvider);
  }

  // ---- 認証アクション ----------------------------------------------------

  /// メール新規登録。匿名ユーザーがいる場合は昇格（uid 不変・データ保持）。
  ///
  /// メール確認（Confirm email）が有効な場合は、登録/昇格の時点ではサインインされず
  /// 確認メールが送られる。確認待ち（メール内リンクの確認が必要）なら true を返す。
  /// 確認 OFF の場合は即サインイン状態になり false を返す（従来挙動）。
  Future<bool> signUpWithEmail(String email, String password) async {
    _awaitingOAuthRedirect = false;
    final user = _client.auth.currentUser;
    if (user != null && user.isAnonymous) {
      // 匿名→永続アカウントへ昇格。確認有効時は確認まで保留（emailConfirmedAt が null）。
      // emailRedirectTo で、確認メールのリンクを開いた後アプリのディープリンクへ戻す。
      final res = await _client.auth.updateUser(
        UserAttributes(email: email, password: password),
        emailRedirectTo: kAuthRedirectUrl,
      );
      return res.user?.emailConfirmedAt == null;
    } else {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: kAuthRedirectUrl,
      );
      // 確認有効時はセッションが張られない（= 確認待ち）。
      return res.session == null;
    }
  }

  /// メールログイン（別アカウントへの切替を含む）。
  Future<void> signInWithEmail(String email, String password) async {
    _awaitingOAuthRedirect = false;
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Google でサインイン / 連携する（ブラウザ OAuth）。
  ///
  /// 匿名（ゲスト）の場合は linkIdentity で連携し、uid 不変のまま
  /// ポイント・クーポン・履歴を引き継ぐ。それ以外は通常サインイン（別アカウントへの
  /// 切替を含む）。いずれもカスタムタブを起動するだけで、認証成立は
  /// onAuthStateChange 側（_handleAuthenticated）で処理される。
  Future<void> signInWithGoogle() async {
    final user = _client.auth.currentUser;
    // ディープリンク復帰時に push 済み認証ページを畳むためのフラグ。
    _awaitingOAuthRedirect = true;
    try {
      if (user != null && user.isAnonymous) {
        await _client.auth.linkIdentity(
          OAuthProvider.google,
          redirectTo: kAuthRedirectUrl,
        );
      } else {
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kAuthRedirectUrl,
        );
      }
    } catch (e) {
      // 起動自体に失敗したらフラグを戻す（後続の正常サインインを誤って畳まないため）。
      _awaitingOAuthRedirect = false;
      rethrow;
    }
  }

  /// ログイン中のアカウントに Google を連携する（ブラウザ OAuth）。
  ///
  /// signInWithGoogle と違い _awaitingOAuthRedirect は立てない。連携は
  /// プロフィールから行い、戻った後もプロフィールに留まって連携済み表示へ
  /// 更新されるだけにしたいため（push 済みページを畳まない）。
  Future<void> linkGoogle() async {
    _awaitingOAuthRedirect = false;
    await _client.auth.linkIdentity(
      OAuthProvider.google,
      redirectTo: kAuthRedirectUrl,
    );
  }

  /// Google 連携を解除する。
  ///
  /// 連携手段が1つしか無い場合はアカウントにログインできなくなるため拒否する。
  Future<void> unlinkGoogle() async {
    _awaitingOAuthRedirect = false;
    final identities = _client.auth.currentUser?.identities ?? const [];
    if (identities.length <= 1) {
      throw AuthException('他のログイン方法がないため、Google 連携を解除できません。');
    }
    UserIdentity? google;
    for (final id in identities) {
      if (id.provider == 'google') {
        google = id;
        break;
      }
    }
    if (google == null) {
      throw AuthException('Google 連携が見つかりません。');
    }
    await _client.auth.unlinkIdentity(google);
    // unlinkIdentity はローカルセッションを自動更新しない。トークンを更新して
    // identities / app_metadata.providers の最新状態を反映する（authState 発火で
    // accountStatusProvider 経由のカード表示が連携解除済みに更新される）。
    await _client.auth.refreshSession();
  }

  Future<void> signOut() async {
    _awaitingOAuthRedirect = false;
    await _client.auth.signOut();
  }

  /// アカウントを完全削除（退会）する。delete_account Edge Function が
  /// auth.users を hard delete（FK カスケードでユーザーデータも削除）した後、
  /// ローカルセッションを signOut で破棄する。signOut で _handleSignedOut が走り、
  /// guestAck=false → ゲートが AuthLanding に戻る。
  Future<void> deleteAccount() async {
    _awaitingOAuthRedirect = false;
    await _client.functions.invoke('delete_account');
    // 既にサーバ側で削除済みのセッションに対する global signOut は、サーバへの
    // 失効リクエストが失敗して例外になり得る（削除成功なのに UI が失敗表示になる）。
    // ローカルセッションのみ破棄する local scope を使う。
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  /// パスワード再設定メールを送信。リンクは kAuthRedirectUrl に戻る。
  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(
      email,
      redirectTo: kAuthRedirectUrl,
    );
  }

  /// 復元セッション中に新しいパスワードを設定する。
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// ログイン中にパスワードを変更する。
  ///
  /// 現在のパスワードで signInWithPassword して本人確認（誤入力なら AuthException）
  /// したうえで updateUser で更新する。再認証はゲートを揺らさない（uid 不変・
  /// _awaitingOAuthRedirect も立てていないため画面は畳まれない）。
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    // 直前にキャンセルされた Google OAuth のフラグが残っていると、ここでの
    // 再認証（signInWithPassword）で _handleAuthenticated が誤って画面を畳む。
    // 念のため明示的にリセットする。
    _awaitingOAuthRedirect = false;
    final email = _client.auth.currentUser?.email;
    if (email == null) {
      throw AuthException('アカウントにメールアドレスが設定されていません。');
    }
    await _client.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// ゲストとして利用を続行。匿名ユーザーが無ければ作成し、承認フラグを立てる。
  Future<void> continueAsGuest() async {
    _awaitingOAuthRedirect = false;
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
