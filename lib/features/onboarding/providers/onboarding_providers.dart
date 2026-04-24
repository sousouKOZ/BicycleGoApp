import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// オンボーディング完了フラグの永続化。
/// 初回起動で false → オンボ表示 → 完了時に true に更新。
class OnboardingCompleted extends StateNotifier<bool> {
  OnboardingCompleted() : super(false) {
    _load();
  }

  static const _key = 'onboarding_completed_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    state = true;
  }
}

final onboardingCompletedProvider =
    StateNotifierProvider<OnboardingCompleted, bool>(
  (_) => OnboardingCompleted(),
);
