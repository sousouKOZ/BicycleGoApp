import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/home/presentation/home_shell.dart';
import 'features/onboarding/presentation/onboarding_page.dart';
import 'features/onboarding/providers/onboarding_providers.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingDone = ref.watch(onboardingCompletedProvider);
    return MaterialApp(
      title: 'BicycleGo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: onboardingDone ? const HomeShell() : const OnboardingPage(),
    );
  }
}
