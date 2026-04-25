import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
import '../../coupons/domain/coupon.dart';
import '../../coupons/presentation/widgets/swipe_to_use.dart';
import '../../coupons/providers/coupon_providers.dart';
import '../../parking/domain/parking_session.dart';
import '../../parking/providers/session_providers.dart';
import '../../user/providers/user_providers.dart';
import '../data/notification_service.dart';
import '../providers/session_history_providers.dart';

class CouponEarnedPage extends ConsumerStatefulWidget {
  const CouponEarnedPage({super.key});

  @override
  ConsumerState<CouponEarnedPage> createState() => _CouponEarnedPageState();
}

class _CouponEarnedPageState extends ConsumerState<CouponEarnedPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burstController;

  @override
  void initState() {
    super.initState();
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.heavyImpact();
      _burstController.forward();
    });
  }

  @override
  void dispose() {
    _burstController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final coupon = ref.watch(latestEarnedCouponProvider);
    if (coupon == null) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: Text('クーポンが見つかりませんでした')),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _CelebrationBanner(onShare: () => _share(coupon)),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: _SparkleBurst(controller: _burstController),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: _CouponCard(coupon: coupon)),
              const SizedBox(height: 16),
              SwipeToUse(
                onCompleted: () => _redeem(context, ref, coupon),
                label: 'スワイプして使用',
                completedLabel: '使用済み ✓',
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _keepParkedAndExit(context, ref),
                child: Text(
                  'あとで使う（駐輪は継続中）',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: context.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _share(Coupon coupon) async {
    HapticFeedback.selectionClick();
    final text =
        '#BicycleGo で15分駐輪したら ${coupon.storeName} の「${coupon.benefit}」クーポンが届いた！';
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('シェア用テキストをコピーしました')),
    );
  }

  Future<void> _redeem(
      BuildContext context, WidgetRef ref, Coupon coupon) async {
    final api = ref.read(apiClientProvider);
    final userId = ref.read(currentUserIdProvider);
    await api.redeemCoupon(userId: userId, couponId: coupon.id);
    final session = ref.read(activeSessionProvider);
    if (session != null) {
      await api.endSession(session.id);
      await ref
          .read(sessionHistoryProvider.notifier)
          .updateCompletedAt(session.id, DateTime.now());
    }
    await NotificationService.instance.cancelSessionReminders();
    ref.read(activeSessionProvider.notifier).state = null;
    ref.read(activeParkingInfoProvider.notifier).state = null;
    ref.read(latestEarnedCouponProvider.notifier).state = null;
    ref.invalidate(userCouponsProvider);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ありがとうございました'),
        content: Text('${coupon.storeName} でご利用いただきました。'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  /// クーポンは保存し、駐輪セッションを `parked` 状態として継続する。
  /// 自転車を出すタイミングでミニバーから出庫操作（CheckoutSheet）を行う。
  void _keepParkedAndExit(BuildContext context, WidgetRef ref) {
    NotificationService.instance.cancelSessionReminders();
    final session = ref.read(activeSessionProvider);
    if (session != null) {
      ref.read(activeSessionProvider.notifier).state =
          session.copyWith(status: ParkingSessionStatus.parked);
    }
    ref.read(latestEarnedCouponProvider.notifier).state = null;
    ref.invalidate(userCouponsProvider);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

class _CelebrationBanner extends StatelessWidget {
  final VoidCallback? onShare;
  const _CelebrationBanner({this.onShare});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF18B27A),
            Color(0xFF2E7CF6),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3318B27A),
            blurRadius: 28,
            spreadRadius: -8,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.celebration_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '15分達成！',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '隠れた名店を知るきっかけをあなたに',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (onShare != null)
            IconButton(
              tooltip: 'シェア',
              icon: const Icon(Icons.ios_share_rounded, color: Colors.white),
              onPressed: onShare,
            ),
        ],
      ),
    );
  }
}

/// クーポン獲得時にバナー周辺で短時間だけ星形パーティクルを散らす演出。
class _SparkleBurst extends StatelessWidget {
  final AnimationController controller;
  const _SparkleBurst({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _SparkleBurstPainter(progress: controller.value),
        );
      },
    );
  }
}

class _SparkleBurstPainter extends CustomPainter {
  final double progress;
  static final List<_SparkleSpec> _specs = List.generate(14, (i) {
    final rng = math.Random(i * 31);
    return _SparkleSpec(
      angle: (i / 14) * math.pi * 2 + rng.nextDouble() * 0.4,
      distance: 80 + rng.nextDouble() * 80,
      size: 6 + rng.nextDouble() * 6,
      hueShift: rng.nextDouble(),
    );
  });

  _SparkleBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    final eased = Curves.easeOutQuad.transform(progress);
    final fade = 1.0 - Curves.easeIn.transform(progress);

    for (final spec in _specs) {
      final dx = math.cos(spec.angle) * spec.distance * eased;
      final dy = math.sin(spec.angle) * spec.distance * eased;
      final paint = Paint()
        ..color = (spec.hueShift < 0.5
                ? Colors.white
                : const Color(0xFFFFE082))
            .withValues(alpha: fade);
      canvas.drawCircle(center + Offset(dx, dy), spec.size * (1 - eased * 0.5),
          paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparkleBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _SparkleSpec {
  final double angle;
  final double distance;
  final double size;
  final double hueShift;
  const _SparkleSpec({
    required this.angle,
    required this.distance,
    required this.size,
    required this.hueShift,
  });
}

class _CouponCard extends StatelessWidget {
  final Coupon coupon;
  const _CouponCard({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expires = coupon.expiresAt;
    final expiresLabel =
        '${expires.year}/${expires.month.toString().padLeft(2, '0')}/${expires.day.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: GlassDecoration.accentCard(context, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_offer_rounded,
                    color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '店舗',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: context.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      coupon.storeName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Text(
                  coupon.distanceTier.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            coupon.benefit,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: AppColors.accent,
              letterSpacing: -1.2,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            coupon.title,
            style: theme.textTheme.bodyLarge,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 16, color: context.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('有効期限：$expiresLabel まで',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '※会計時に店舗スタッフの面前でスワイプしてご利用ください。',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
