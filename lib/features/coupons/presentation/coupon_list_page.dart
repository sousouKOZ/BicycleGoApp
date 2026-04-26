import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
import '../../stores/domain/store.dart';
import '../../stores/presentation/store_preview_sheet.dart';
import '../../stores/providers/store_providers.dart';
import '../../user/providers/user_providers.dart';
import '../domain/coupon.dart';
import '../providers/coupon_filter_providers.dart';
import '../providers/coupon_providers.dart';
import 'coupon_detail_page.dart';
import 'widgets/swipe_to_use.dart';

class CouponListPage extends ConsumerWidget {
  const CouponListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncCoupons = ref.watch(userCouponsProvider);
    final asyncStores = ref.watch(storesProvider);
    return Scaffold(
      body: SafeArea(
        child: asyncCoupons.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('読み込み失敗: $e')),
          data: (coupons) {
            final stores = asyncStores.asData?.value ?? const <Store>[];
            final query =
                ref.watch(couponSearchQueryProvider).trim().toLowerCase();
            final sortMode = ref.watch(couponSortModeProvider);

            bool matchesQuery(Coupon c) =>
                query.isEmpty ||
                c.storeName.toLowerCase().contains(query) ||
                c.benefit.toLowerCase().contains(query);

            int compare(Coupon a, Coupon b) {
              switch (sortMode) {
                case CouponSortMode.expiringSoon:
                  return a.expiresAt.compareTo(b.expiresAt);
                case CouponSortMode.newest:
                  return b.issuedAt.compareTo(a.issuedAt);
              }
            }

            final owned = coupons
                .where((c) =>
                    c.status == CouponStatus.owned &&
                    !c.isExpired &&
                    matchesQuery(c))
                .toList()
              ..sort(compare);
            final used = coupons
                .where((c) =>
                    c.status == CouponStatus.used && matchesQuery(c))
                .toList()
              ..sort((a, b) =>
                  (b.usedAt ?? b.issuedAt).compareTo(a.usedAt ?? a.issuedAt));
            final expired = coupons
                .where((c) =>
                    (c.status == CouponStatus.expired ||
                        (c.status == CouponStatus.owned && c.isExpired)) &&
                    matchesQuery(c))
                .toList()
              ..sort((a, b) => b.expiresAt.compareTo(a.expiresAt));

            final visibleStores = query.isEmpty
                ? stores
                : stores
                    .where((s) =>
                        s.name.toLowerCase().contains(query) ||
                        s.benefit.toLowerCase().contains(query))
                    .toList();

            if (coupons.isEmpty && stores.isEmpty) {
              return const _EmptyState();
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(userCouponsProvider);
                ref.invalidate(storesProvider);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  _PageHeader(
                    totalOwned: owned.length,
                    totalDistributing: visibleStores.length,
                  ),
                  const SizedBox(height: 16),
                  const _CouponFilterBar(),
                  const SizedBox(height: 16),
                  if (visibleStores.isNotEmpty) ...[
                    const _SectionHeader(
                      title: '配信中',
                      subtitle: '近くの提携駐輪場に15分停めると獲得できます',
                      accent: AppColors.accent,
                    ),
                    const SizedBox(height: 12),
                    ...visibleStores
                        .map((s) => _DistributingCouponCard(store: s)),
                    const SizedBox(height: 24),
                  ],
                  if (owned.isNotEmpty) ...[
                    _SectionHeader(
                      title: '利用可能',
                      subtitle: sortMode == CouponSortMode.expiringSoon
                          ? '期限が近い順に表示中'
                          : '会計時にスワイプで消込',
                      accent: AppColors.success,
                    ),
                    const SizedBox(height: 12),
                    ...owned.map((c) => _CouponCard(coupon: c)),
                    const SizedBox(height: 24),
                  ],
                  if (used.isNotEmpty) ...[
                    const _SectionHeader(
                      title: '使用済み',
                      subtitle: 'ご利用ありがとうございました',
                      accent: AppColors.onSurfaceSecondary,
                    ),
                    const SizedBox(height: 12),
                    ...used.map((c) => _CouponCard(coupon: c)),
                    const SizedBox(height: 24),
                  ],
                  if (expired.isNotEmpty) ...[
                    const _SectionHeader(
                      title: '期限切れ',
                      subtitle: '—',
                      accent: AppColors.danger,
                    ),
                    const SizedBox(height: 12),
                    ...expired.map((c) => _CouponCard(coupon: c)),
                  ],
                  if (owned.isEmpty &&
                      used.isEmpty &&
                      expired.isEmpty &&
                      visibleStores.isEmpty &&
                      query.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Center(
                        child: Text(
                          '「$query」に一致するクーポンはありません',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  final int totalOwned;
  final int totalDistributing;
  const _PageHeader({
    required this.totalOwned,
    required this.totalDistributing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'クーポン',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '利用可能 $totalOwned件・配信中 $totalDistributing件',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _DistributingCouponCard extends StatelessWidget {
  final Store store;
  const _DistributingCouponCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: GlassDecoration.accentCard(context, radius: 22),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) => StorePreviewSheet(store: store),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CategoryChip(label: store.category.label),
                    const SizedBox(width: 8),
                    _StatusChip(
                      icon: Icons.local_offer,
                      label: '配信中',
                      color: AppColors.accent,
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: context.textSecondary),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  store.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  store.benefit,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.accent,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: GlassDecoration.pill(context),
              child: Icon(Icons.confirmation_number_rounded,
                  size: 40, color: AppColors.accent),
            ),
            const SizedBox(height: 16),
            Text('まだクーポンはありません',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
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
    final isUsable = coupon.isUsable;
    final remaining = _formatRemaining(coupon.expiresAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: isUsable
          ? GlassDecoration.accentCard(context, radius: 22)
          : GlassDecoration.light(context, radius: 22, opacity: 0.72),
      clipBehavior: Clip.antiAlias,
      child: Opacity(
        opacity: isUsable ? 1.0 : 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 詳細遷移用のタップ領域。SwipeToUse とジェスチャーが衝突しないよう
            // Material/InkWell はカード上部のみに限定する。
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CouponDetailPage(coupon: coupon),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      18, 16, 18, isUsable ? 12 : 16),
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
                          _DistanceChip(
                            label: coupon.distanceTier.label,
                            isUsable: isUsable,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(coupon.benefit,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                            color: isUsable
                                ? AppColors.accent
                                : context.textSecondary,
                          )),
                      const SizedBox(height: 4),
                      Text(coupon.title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.textSecondary,
                          )),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 15,
                              color: isUsable
                                  ? context.textSecondary
                                  : AppColors.danger),
                          const SizedBox(width: 6),
                          Text(
                            coupon.status == CouponStatus.used
                                ? '使用済み'
                                : coupon.isExpired
                                    ? '期限切れ'
                                    : '期限：$remaining',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isUsable
                                  ? context.textSecondary
                                  : AppColors.danger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (isUsable)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: SwipeToUse(
                  label: 'スワイプして使用',
                  completedLabel: '使用済み ✓',
                  onCompleted: () => _redeem(context, ref),
                ),
              ),
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

class _CategoryChip extends StatelessWidget {
  final String label;
  const _CategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.subtleBorder,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: context.textPrimary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistanceChip extends StatelessWidget {
  final String label;
  final bool isUsable;
  const _DistanceChip({required this.label, required this.isUsable});

  @override
  Widget build(BuildContext context) {
    final color = isUsable ? AppColors.success : context.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.3,
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
                    color: context.textPrimary,
                  )),
              Text(subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.textSecondary,
                  )),
            ],
          ),
        ],
      ),
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

class _CouponFilterBar extends ConsumerStatefulWidget {
  const _CouponFilterBar();

  @override
  ConsumerState<_CouponFilterBar> createState() => _CouponFilterBarState();
}

class _CouponFilterBarState extends ConsumerState<_CouponFilterBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: ref.read(couponSearchQueryProvider),
    );
    _controller.addListener(() {
      final v = _controller.text;
      if (ref.read(couponSearchQueryProvider) != v) {
        ref.read(couponSearchQueryProvider.notifier).state = v;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortMode = ref.watch(couponSortModeProvider);
    final query = ref.watch(couponSearchQueryProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: GlassDecoration.light(context, radius: 14),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '店名・特典で検索',
              prefixIcon:
                  Icon(Icons.search, color: context.textSecondary),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: context.textSecondary),
                      onPressed: () => _controller.clear(),
                    ),
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.sort_rounded,
                size: 16, color: context.textSecondary),
            const SizedBox(width: 6),
            Text(
              '並び順',
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final mode in CouponSortMode.values) ...[
                      _SortChip(
                        label: mode.label,
                        isActive: sortMode == mode,
                        onTap: () => ref
                            .read(couponSortModeProvider.notifier)
                            .state = mode,
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _SortChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive ? AppColors.accent : context.subtleBorder,
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: isActive ? AppColors.accent : context.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
