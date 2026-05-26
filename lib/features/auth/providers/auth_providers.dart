import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../onboarding/providers/onboarding_providers.dart';
import '../domain/account_status.dart';

/// アプリのトップレベルで表示すべき画面。
enum AppGate { onboarding, authLanding, home }

/// MaterialApp の Navigator にアタッチするキー。
/// パスワード再設定リンク（passwordRecovery）など、ウィジェット context の外から
/// 画面遷移したいケースで使う。
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Supabase の認証状態ストリーム。サインイン/アウト/トークン更新で発火する。
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

/// 現在の auth ユーザー。authState を watch して切替時に再評価される。
final currentAuthUserProvider = Provider<User?>((ref) {
  // ストリームを購読して変化を拾う（値自体は currentUser から取る）。
  ref.watch(authStateProvider);
  return Supabase.instance.client.auth.currentUser;
});

/// ゲスト（未ログイン or 匿名）か。
final isGuestProvider = Provider<bool>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  return user == null || user.isAnonymous;
});

/// 「ゲストで続ける」をユーザーが承認したか（SharedPreferences 永続化）。
/// onboardingCompletedProvider と同じパターン。
class GuestAcknowledged extends StateNotifier<bool> {
  GuestAcknowledged() : super(false) {
    _load();
  }

  static const _key = 'guest_acknowledged_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> setAcknowledged(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
    state = value;
  }
}

final guestAcknowledgedProvider =
    StateNotifierProvider<GuestAcknowledged, bool>(
  (_) => GuestAcknowledged(),
);

/// HomeShell をフル再マウントするためのキー。auth ユーザー切替時にインクリメントし、
/// 命令的な Realtime 購読（home_session_$uid）を dispose→再 init させる。
final authSessionKeyProvider = StateProvider<int>((_) => 0);

/// トップレベルのゲート判定。
final appGateProvider = Provider<AppGate>((ref) {
  final onboardingDone = ref.watch(onboardingCompletedProvider);
  if (!onboardingDone) return AppGate.onboarding;

  final isGuest = ref.watch(isGuestProvider);
  final guestAck = ref.watch(guestAcknowledgedProvider);
  // 非匿名（ログイン済み）ならホーム。匿名でもゲスト承認済みならホーム。
  if (!isGuest || guestAck) return AppGate.home;
  return AppGate.authLanding;
});

/// auth user からアカウント連携状態を導出。
final accountStatusProvider = Provider<AccountStatus>((ref) {
  final user = ref.watch(currentAuthUserProvider);
  if (user == null || user.isAnonymous) {
    return AccountStatus.guest;
  }
  final providers = user.appMetadata['providers'];
  final providerList = providers is List
      ? providers.map((e) => e.toString()).toList()
      : <String>[];
  final isGoogle = providerList.contains('google');
  return AccountStatus(
    kind: isGoogle ? AccountKind.googleLinked : AccountKind.emailLinked,
    email: user.email,
    providers: providerList,
  );
});
