import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_providers.dart';
import 'features/auth/presentation/auth_landing_page.dart';
import 'features/auth/presentation/set_new_password_page.dart';
import 'features/auth/providers/auth_controller.dart';
import 'features/auth/providers/auth_providers.dart';
import 'features/home/presentation/home_shell.dart';
import 'features/onboarding/presentation/onboarding_page.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // AuthController をアプリ生存期間維持（onAuthStateChange の購読・再マウント制御）。
    ref.watch(authControllerProvider);

    // パスワード再設定リンクを開くと passwordRecovery が発火。
    // 復元セッション中に新パスワード設定画面を最前面に出す。
    ref.listen<AsyncValue<AuthState>>(authStateProvider, (_, next) {
      if (next.valueOrNull?.event == AuthChangeEvent.passwordRecovery) {
        rootNavigatorKey.currentState?.push(
          MaterialPageRoute(builder: (_) => const SetNewPasswordPage()),
        );
      }
    });

    final gate = ref.watch(appGateProvider);
    final themeMode = ref.watch(themeModeProvider);

    final Widget home;
    switch (gate) {
      case AppGate.onboarding:
        home = const OnboardingPage();
        break;
      case AppGate.authLanding:
        home = const AuthLandingPage();
        break;
      case AppGate.home:
        // auth ユーザー切替時に key をバンプして HomeShell をフル再マウントし、
        // Realtime チャンネル(home_session_$uid)を dispose→再 init させる。
        home = HomeShell(
          key: ValueKey(ref.watch(authSessionKeyProvider)),
        );
        break;
    }

    return MaterialApp(
      title: 'BicycleGo',
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // 端末の「文字サイズ／表示サイズ」設定が大きい場合の UI 見切れを防ぐため、
      // 文字スケールの上限を 1.3 倍にクランプする（縮小側は端末設定を尊重）。
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 1.3),
          ),
          child: child!,
        );
      },
      home: home,
    );
  }
}
