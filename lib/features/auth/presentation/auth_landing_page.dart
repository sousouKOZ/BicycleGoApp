import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/auth_controller.dart';
import 'email_login_page.dart';
import 'email_signup_page.dart';

/// オンボーディング後に表示するログイン/新規登録のランディング画面。
/// 「ゲストで続ける」で匿名利用も可能。
///
/// ⚠️ ユーザースコープ provider（points / coupons / history / profile）は
/// 一切読まないこと（auth 切替直後にクラッシュさせないため）。
class AuthLandingPage extends ConsumerStatefulWidget {
  const AuthLandingPage({super.key});

  @override
  ConsumerState<AuthLandingPage> createState() => _AuthLandingPageState();
}

class _AuthLandingPageState extends ConsumerState<AuthLandingPage> {
  bool _busy = false;

  Future<void> _continueAsGuest() async {
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider).continueAsGuest();
      // guestAcknowledged=true で appGate が home になり、この画面は外れる。
    } catch (_) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('開始できませんでした。通信環境をご確認ください。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 620;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 52,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: compact ? 8 : 32),
                    Container(
                      width: compact ? 72 : 80,
                      height: compact ? 72 : 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.accentAlt],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.35),
                            blurRadius: 24,
                            spreadRadius: -4,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.pedal_bike_rounded,
                        color: Colors.white,
                        size: compact ? 38 : 42,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'BicycleGo',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '駐輪してクーポンを貯めよう',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                    SizedBox(height: compact ? 40 : 72),
                    ElevatedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const EmailSignupPage(),
                                ),
                              ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('アカウントを作成'),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const EmailLoginPage(),
                                ),
                              ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('ログイン'),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: _busy ? null : _continueAsGuest,
                      child: _busy
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('ゲストで続ける'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ゲストでもすべての機能を使えます。'
                      'あとからアカウントを作成すればデータを引き継げます。',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: compact ? 8 : 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
