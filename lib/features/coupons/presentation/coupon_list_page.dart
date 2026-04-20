import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../user/providers/user_providers.dart';
import '../domain/coupon.dart';
import '../providers/coupon_providers.dart';
import 'widgets/swipe_to_use.dart';

class CouponListPage extends ConsumerWidget {
  const CouponListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(userCouponsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('クーポン')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('読み込み失敗: $e')),
        data: (coupons) {
          if (coupons.isEmpty) {
            return const _EmptyState();
          }
          final owned =
              coupons.where((c) => c.status == CouponStatus.owned).toList();
          final used =
              coupons.where((c) => c.status == CouponStatus.used).toList();
          final expired = coupons
              .where((c) =>
                  c.status == CouponStatus.expired ||
                  (c.status == CouponStatus.owned && c.isExpired))
              .toList();
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(userCouponsProvider),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (owned.isNotEmpty) ...[
                  const _SectionHeader(
                    title: '利用可能',
                    subtitle: '会計時にスワイプで消込',
                  ),
                  const SizedBox(height: 8),
                  ...owned.map((c) => _CouponCard(coupon: c)),
                  const SizedBox(height: 18),
                ],
                if (used.isNotEmpty) ...[
                  const _SectionHeader(
                    title: '使用済み',
                    subtitle: 'ご利用ありがとうございました',
                  ),
                  const SizedBox(height: 8),
                  ...used.map((c) => _CouponCard(coupon: c)),
                  const SizedBox(height: 18),
                ],
                if (expired.isNotEmpty) ...[
                  const _SectionHeader(
                    title: '期限切れ',
                    subtitle: '—',
                  ),
                  const SizedBox(height: 8),
                  ...expired.map((c) => _CouponCard(coupon: c)),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎟', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text('まだクーポンはありません',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              '提携駐輪場に15分停めるだけで\n自動的にクーポンが届きます',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CouponCard extends ConsumerWidget {
  final Coupon coupon;
  const _CouponCard({required this.coupon});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isUsable = coupon.isUsable;
    final remaining = _formatRemaining(coupon.expiresAt);
    final surface = isUsable ? scheme.surface : scheme.surfaceVariant.withOpacity(0.6);
    final accent = isUsable ? scheme.primaryContainer : scheme.outlineVariant;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            surface,
            Color.alphaBlend(accent.withOpacity(0.5), surface),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isUsable
              ? scheme.primary.withOpacity(0.2)
              : scheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(coupon.storeName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      )),
                ),
                _Badge(
                  label: coupon.distanceTier.label,
                  color: isUsable ? scheme.tertiary : scheme.outline,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(coupon.benefit,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isUsable ? scheme.primary : scheme.outline,
                )),
            const SizedBox(height: 6),
            Text(coupon.title, style: theme.textTheme.bodySmall),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 16,
                    color: isUsable ? scheme.tertiary : scheme.error),
                const SizedBox(width: 4),
                Text(
                  coupon.status == CouponStatus.used
                      ? '使用済み'
                      : coupon.isExpired
                          ? '期限切れ'
                          : '期限：$remaining',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            if (isUsable) ...[
              const SizedBox(height: 12),
              SwipeToUse(
                label: 'スワイプして使用',
                completedLabel: '使用済み ✓',
                onCompleted: () => _redeem(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _redeem(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiClientProvider);
    final userId = ref.read(currentUserIdProvider);
    await api.redeemCoupon(userId: userId, couponId: coupon.id);
    ref.invalidate(userCouponsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${coupon.storeName}で使用しました')),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          )),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(subtitle,
            style:
                theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
      ],
    );
  }
}

String _formatRemaining(DateTime expiresAt) {
  final now = DateTime.now();
  final diff = expiresAt.difference(now);
  if (diff.isNegative) return '—';
  final days = diff.inDays;
  final hours = diff.inHours % 24;
  if (days >= 1) return 'あと$days日 $hours時間';
  final minutes = diff.inMinutes % 60;
  if (diff.inHours >= 1) return 'あと${diff.inHours}時間 $minutes分';
  return 'あと${diff.inMinutes}分';
}
