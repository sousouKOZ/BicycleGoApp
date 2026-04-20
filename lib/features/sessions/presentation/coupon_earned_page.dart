import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../coupons/domain/coupon.dart';
import '../../coupons/presentation/widgets/swipe_to_use.dart';
import '../../coupons/providers/coupon_providers.dart';
import '../../parking/providers/session_providers.dart';
import '../../user/providers/user_providers.dart';

class CouponEarnedPage extends ConsumerWidget {
  const CouponEarnedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coupon = ref.watch(latestEarnedCouponProvider);
    if (coupon == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('クーポン獲得')),
        body: const Center(child: Text('クーポンが見つかりませんでした')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('クーポン獲得！'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const _CelebrationBanner(),
              const SizedBox(height: 16),
              Expanded(child: _CouponCard(coupon: coupon)),
              const SizedBox(height: 16),
              SwipeToUse(
                onCompleted: () => _redeem(context, ref, coupon),
                label: 'スワイプして使用',
                completedLabel: '使用済み ✓',
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _backToHome(context, ref),
                child: const Text('あとで使う（クーポン一覧に保存）'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _redeem(BuildContext context, WidgetRef ref, Coupon coupon) async {
    final api = ref.read(apiClientProvider);
    final userId = ref.read(currentUserIdProvider);
    await api.redeemCoupon(userId: userId, couponId: coupon.id);
    final session = ref.read(activeSessionProvider);
    if (session != null) {
      await api.endSession(session.id);
    }
    ref.read(activeSessionProvider.notifier).state = null;
    ref.read(latestEarnedCouponProvider.notifier).state = null;
    ref.invalidate(userCouponsProvider);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('ありがとうございました'),
        content: Text('${coupon.storeName} でご利用いただきました。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _backToHome(BuildContext context, WidgetRef ref) {
    ref.read(activeSessionProvider.notifier).state = null;
    ref.read(latestEarnedCouponProvider.notifier).state = null;
    ref.invalidate(userCouponsProvider);
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
}

class _CelebrationBanner extends StatelessWidget {
  const _CelebrationBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [scheme.tertiaryContainer, scheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '15分達成！',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '隠れた名店を知るきっかけをあなたに',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final Coupon coupon;
  const _CouponCard({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final expires = coupon.expiresAt;
    final expiresLabel =
        '${expires.year}/${expires.month.toString().padLeft(2, '0')}/${expires.day.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withOpacity(0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  coupon.storeName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  coupon.distanceTier.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            coupon.benefit,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            coupon.title,
            style: theme.textTheme.bodyLarge,
          ),
          const Spacer(),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: scheme.outline),
              const SizedBox(width: 6),
              Text('有効期限：$expiresLabel まで',
                  style: theme.textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '※会計時に店舗スタッフの面前でスワイプしてご利用ください。',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
          ),
        ],
      ),
    );
  }
}
