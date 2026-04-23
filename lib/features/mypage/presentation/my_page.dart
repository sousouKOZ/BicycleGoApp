import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
import '../../coupons/domain/coupon.dart';
import '../../coupons/providers/coupon_providers.dart';
import '../../points/providers/points_providers.dart';

class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pointsProvider);
    final asyncCoupons = ref.watch(userCouponsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const _PageHeader(),
            const SizedBox(height: 20),
            _PointsCard(points: points),
            const SizedBox(height: 24),
            const _SectionHeader(
              title: '利用可能クーポン',
              subtitle: '15分駐輪で自動発行されたクーポン',
              accent: AppColors.success,
            ),
            const SizedBox(height: 12),
            asyncCoupons.when(
              loading: () => Padding(
                padding: const EdgeInsets.all(24),
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('読み込み失敗: $e'),
              data: (list) {
                final usable = list
                    .where((c) =>
                        c.status == CouponStatus.owned && !c.isExpired)
                    .toList();
                if (usable.isEmpty) {
                  return Container(
                    decoration: GlassDecoration.light(radius: 20),
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 18, color: AppColors.onSurfaceSecondary),
                        const SizedBox(width: 10),
                        Text(
                          '利用可能なクーポンはありません',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }
                return Column(
                  children: usable
                      .map((c) => _OwnedCouponTile(coupon: c))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            const _SectionHeader(
              title: 'メニュー',
              subtitle: '',
              accent: AppColors.accentAlt,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: GlassDecoration.light(radius: 20),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.history_rounded,
                    title: '駐輪履歴',
                    hint: '準備中',
                    onTap: () {},
                  ),
                  Divider(
                    height: 1,
                    color: AppColors.onSurfaceSecondary.withValues(alpha: 0.1),
                    indent: 56,
                  ),
                  _MenuTile(
                    icon: Icons.settings_rounded,
                    title: '設定',
                    hint: '準備中',
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'マイページ',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ポイントとクーポンをここで管理',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  final int points;
  const _PointsCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E7CF6),
            Color(0xFF7C5CFF),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332E7CF6),
            blurRadius: 30,
            spreadRadius: -8,
            offset: Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                '現在のポイント',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$points',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'pt',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                '交換する',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnedCouponTile extends StatelessWidget {
  final Coupon coupon;
  const _OwnedCouponTile({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expires = coupon.expiresAt;
    final expiresLabel =
        '${expires.month}/${expires.day.toString().padLeft(2, '0')}まで';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: GlassDecoration.light(radius: 18),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.confirmation_number_rounded,
                      color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        coupon.benefit,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${coupon.storeName}・$expiresLabel',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppColors.onSurfaceSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String hint;
  final VoidCallback onTap;
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.onSurfaceSecondary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(icon, size: 18, color: AppColors.onSurfacePrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                hint,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppColors.onSurfaceSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.onSurfaceSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  )),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
