import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/onboarding_providers.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _steps = <_Step>[
    _Step(
      icon: Icons.map_rounded,
      title: '近場が満車でも、ちょっと遠くへ',
      body: '駐輪場の空き状況を地図で見つけて、放置自転車ゼロの街へ。\n'
          '少し遠い駐輪場ほど、お得なクーポンが待っています。',
      accent: AppColors.accent,
    ),
    _Step(
      icon: Icons.nfc_rounded,
      title: 'NFCでサッと計測開始',
      body: '駐輪したらロックのタグをスキャンするだけ。\n'
          '15分の駐輪タイマーが自動で始まります。',
      accent: AppColors.accentAlt,
    ),
    _Step(
      icon: Icons.local_offer_rounded,
      title: '15分停めるだけでクーポン獲得',
      body: '15分経過でクーポンが自動発行。\n'
          '通知でお知らせするので、アプリは閉じててOK。\n'
          '近くの隠れた名店との出会いをどうぞ。',
      accent: AppColors.success,
    ),
  ];

  void _next() {
    if (_index >= _steps.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish() async {
    await ref.read(onboardingCompletedProvider.notifier).markCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _steps.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'スキップ',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.onSurfaceSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => _StepView(step: _steps[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_steps.length, (i) {
                  final active = i == _index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active
                          ? AppColors.accent
                          : AppColors.onSurfaceSecondary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isLast ? 'はじめる' : '次へ',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  const _Step({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
  });
}

class _StepView extends StatelessWidget {
  final _Step step;
  const _StepView({required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  step.accent.withValues(alpha: 0.18),
                  step.accent.withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: step.accent.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(step.icon, size: 48, color: step.accent),
          ),
          const SizedBox(height: 32),
          Text(
            step.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.onSurfacePrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            step.body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.onSurfaceSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
