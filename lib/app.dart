import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_providers.dart';
import 'features/auth/presentation/auth_landing_page.dart';
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
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: home,
    );
  }
}
