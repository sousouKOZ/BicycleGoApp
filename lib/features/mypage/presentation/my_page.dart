import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
import '../../../core/theme/usage_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/domain/coupon.dart';
import '../../../core/domain/session_record.dart';
import '../../coupons/presentation/coupon_detail_page.dart';
import '../../coupons/presentation/widgets/coupon_ticket.dart';
import '../../coupons/providers/coupon_providers.dart';
import '../../../core/domain/parking_lot.dart';
import '../../parking/presentation/parking_detail_sheet.dart';
import '../../parking/providers/favorite_providers.dart';
import '../../parking/providers/parking_providers.dart';
import '../../points/presentation/points_exchange_page.dart';
import '../../points/providers/points_providers.dart';
import '../../sessions/presentation/session_history_page.dart';
import '../../sessions/providers/session_history_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../settings/presentation/settings_page.dart';
import '../../user/presentation/user_profile_page.dart';
import '../../user/providers/user_providers.dart';

class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pointsAsync = ref.watch(pointsProvider);
    final asyncCoupons = ref.watch(userCouponsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(pointsProvider);
            ref.invalidate(userCouponsProvider);
            ref.invalidate(userProfileProvider);
            ref.invalidate(sessionHistoryProvider);
            ref.invalidate(favoriteParkingsProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const _PageHeader(),
              const SizedBox(height: 20),
              _PointsCard(
                pointsAsync: pointsAsync,
                onRetry: () => ref.invalidate(pointsProvider),
              ),
              const SizedBox(height: 16),
              const _MonthlyValueSummary(),
              const SizedBox(height: 24),
              const SectionHeader(
                title: '利用可能クーポン',
                subtitle: '15分駐輪で自動発行されたクーポン',
                accent: AppColors.success,
              ),
              const SizedBox(height: 12),
              asyncCoupons.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('読み込み失敗: $e'),
                data: (list) {
                  final usable = list
                      .where(
                          (c) => c.status == CouponStatus.owned && !c.isExpired)
                      .toList();
                  if (usable.isEmpty) {
                    return Container(
                      decoration: GlassDecoration.light(context, radius: 20),
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              size: 18, color: context.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '利用可能なクーポンはありません',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children:
                        usable.map((c) => _OwnedCouponTile(coupon: c)).toList(),
                  );
                },
              ),
              const SizedBox(height: 24),
              asyncCoupons.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (list) {
                  final recentlyUsed = list
                      .where((c) => c.status == CouponStatus.used)
                      .toList()
                    ..sort((a, b) => (b.usedAt ?? b.issuedAt)
                        .compareTo(a.usedAt ?? a.issuedAt));
                  final top = recentlyUsed.take(3).toList();
                  if (top.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionHeader(
                        title: '最近使ったクーポン',
                        subtitle: list
                                    .where((c) => c.status == CouponStatus.used)
                                    .length >
                                3
                            ? 'クーポンタブで全件確認できます'
                            : 'ご利用ありがとうございました',
                        accent: AppColors.onSurfaceSecondary,
                      ),
                      const SizedBox(height: 12),
                      ...top.map((c) => _UsedCouponTile(coupon: c)),
                      const SizedBox(height: 24),
                    ],
                  );
                },
              ),
              const SectionHeader(
                title: 'お気に入り駐輪場',
                subtitle: 'よく使う駐輪場をブックマーク',
                accent: AppColors.warning,
              ),
              const SizedBox(height: 12),
              const _FavoriteParkingSection(),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'メニュー',
                subtitle: '',
                accent: AppColors.accentAlt,
              ),
              const SizedBox(height: 12),
              Container(
                decoration: GlassDecoration.light(context, radius: 20),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final count = ref
                                .watch(sessionHistoryProvider)
                                .valueOrNull
                                ?.length ??
                            0;
                        return _MenuTile(
                          icon: Icons.history_rounded,
                          title: '駐輪履歴',
                          hint: count == 0 ? '未取得' : '$count件',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SessionHistoryPage(),
                            ),
                          ),
                        );
                      },
                    ),
                    Divider(
                      height: 1,
                      color: context.subtleBorder,
                      indent: 56,
                    ),
                    _MenuTile(
                      icon: Icons.settings_rounded,
                      title: '設定',
                      hint: 'テーマ・通知',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsPage(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageHeader extends ConsumerWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileProvider);
    final status = ref.watch(accountStatusProvider);
    // ニックネーム未設定でも、ログイン済みなら「ゲスト」と出さない。
    final displayName = profile.nickname.isNotEmpty
        ? profile.nickname
        : status.fallbackDisplayName;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
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
                  'こんにちは、$displayName さん',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const UserProfilePage(),
                ),
              ),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  profile.initial,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  final AsyncValue<int> pointsAsync;
  final VoidCallback onRetry;
  const _PointsCard({required this.pointsAsync, required this.onRetry});

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
            AppColors.accent,
            AppColors.accentAlt,
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3300A88F),
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
          pointsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
            error: (_, __) => Row(
              children: [
                Text(
                  '残高を取得できません',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: '再読み込み',
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
            data: (points) => Row(
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
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PointsExchangePage(),
                ),
              ),
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

class _MonthlyValueSummary extends ConsumerWidget {
  const _MonthlyValueSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(sessionHistoryStatsProvider);
    final history = ref.watch(sessionHistoryProvider).valueOrNull ??
        const <SessionRecord>[];
    final coupons =
        ref.watch(userCouponsProvider).valueOrNull ?? const <Coupon>[];
    final now = DateTime.now();
    final issuedThisMonth = coupons
        .where(
            (c) => c.issuedAt.year == now.year && c.issuedAt.month == now.month)
        .length;
    final usedThisMonth = coupons
        .where((c) =>
            c.status == CouponStatus.used &&
            c.usedAt != null &&
            c.usedAt!.year == now.year &&
            c.usedAt!.month == now.month)
        .toList();
    final savings = _estimateCouponSavingsYen(usedThisMonth);

    return Container(
      decoration: GlassDecoration.light(context, radius: 22),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.insights_rounded,
                    size: 18, color: AppColors.success),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '今月の北区サマリー',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '駐輪とクーポンの成果',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: '駐輪',
                  value: '${stats.monthSessions}回',
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  label: '獲得',
                  value: '$issuedThisMonth件',
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SummaryMetric(
                  label: savings > 0 ? '節約' : '使用',
                  value: savings > 0 ? '¥$savings' : '${usedThisMonth.length}件',
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _WeekdayUsageBars(history: history),
        ],
      ),
    );
  }

  int _estimateCouponSavingsYen(List<Coupon> coupons) {
    final yenPattern = RegExp(r'(\d+)\s*円');
    var total = 0;
    for (final coupon in coupons) {
      final match = yenPattern.firstMatch(coupon.benefit);
      if (match == null) continue;
      total += int.tryParse(match.group(1) ?? '') ?? 0;
    }
    return total;
  }
}

class _SummaryMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekdayUsageBars extends StatelessWidget {
  final List<SessionRecord> history;
  const _WeekdayUsageBars({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final counts = List<int>.filled(7, 0);
    for (final record in history) {
      if (record.completedAt.year != now.year ||
          record.completedAt.month != now.month) {
        continue;
      }
      counts[record.completedAt.weekday - 1] += 1;
    }
    final maxCount =
        counts.fold<int>(1, (max, count) => count > max ? count : max);
    const labels = ['月', '火', '水', '木', '金', '土', '日'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '曜日別の利用',
          style: theme.textTheme.labelMedium?.copyWith(
            color: context.textSecondary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 68,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < labels.length; i++) ...[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 16,
                            height: 18 + 34 * (counts[i] / maxCount),
                            decoration: BoxDecoration(
                              color: counts[i] == 0
                                  ? context.subtleBorder
                                  : AppColors.accent.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        labels[i],
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (i != labels.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OwnedCouponTile extends StatelessWidget {
  final Coupon coupon;
  const _OwnedCouponTile({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final expiresLabel = '${formatMonthDay(coupon.expiresAt)}まで';
    return MiniCouponTicket(
      stubIcon: Icons.confirmation_number_rounded,
      stubLabel: coupon.distanceTier.label,
      stubColor: AppColors.success,
      benefit: coupon.benefit,
      subtitle: '${coupon.storeName}・$expiresLabel',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CouponDetailPage(coupon: coupon),
        ),
      ),
    );
  }
}

class _UsedCouponTile extends StatelessWidget {
  final Coupon coupon;
  const _UsedCouponTile({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final usedAt = coupon.usedAt;
    final usedLabel =
        usedAt == null ? '使用済み' : '${formatMonthDay(usedAt)} 使用';
    return MiniCouponTicket(
      stubIcon: Icons.check_circle_rounded,
      stubLabel: '使用済',
      stubColor: context.textSecondary,
      benefit: coupon.benefit,
      subtitle: '${coupon.storeName}・$usedLabel',
      dimmed: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CouponDetailPage(coupon: coupon),
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
                  color: context.subtleBorder,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: context.textPrimary),
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
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: context.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteParkingSection extends ConsumerWidget {
  const _FavoriteParkingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteParkingsProvider);
    final asyncLots = ref.watch(parkingLotsProvider);

    return asyncLots.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('読み込み失敗: $e'),
      data: (lots) {
        final favLots =
            lots.where((p) => favorites.contains(p.id)).toList(growable: false);
        if (favLots.isEmpty) {
          return Container(
            decoration: GlassDecoration.light(context, radius: 20),
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.star_border_rounded,
                    size: 18, color: context.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'お気に入りの駐輪場はまだありません\n詳細シートの★をタップで登録できます',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: favLots
              .map((p) => _FavoriteParkingTile(parking: p))
              .toList(growable: false),
        );
      },
    );
  }
}

class _FavoriteParkingTile extends ConsumerWidget {
  final ParkingLot parking;
  const _FavoriteParkingTile({required this.parking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final usage = parking.usageRatePercent;
    final usageColor = parking.usageLevel.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: GlassDecoration.light(context, radius: 18),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            showAppBottomSheet<void>(
              context,
              builder: (_) => ParkingDetailSheet(parking: parking),
            );
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: usageColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.local_parking_rounded,
                      size: 20, color: usageColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parking.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '空き${parking.available}/${parking.capacity}・稼働$usage%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: usageColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'お気に入りを解除',
                  onPressed: () => ref
                      .read(favoriteParkingsProvider.notifier)
                      .toggle(parking.id),
                  icon: Icon(Icons.star_rounded,
                      color: AppColors.warning, size: 22),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
