import 'package:flutter/material.dart';

class CouponListPage extends StatelessWidget {
  const CouponListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 仮データ（あとでAPI/Repositoryに差し替え）
    final activeCoupons = <Coupon>[
      Coupon(
        id: 'c1',
        title: '遠くまで行ってくれてありがとう',
        benefit: 'カフェ 200円引き',
        expiresAt: DateTime.now().add(const Duration(days: 3)),
        status: CouponStatus.active,
        distanceTier: '遠い',
      ),
      Coupon(
        id: 'c2',
        title: '駐輪おつかれさま',
        benefit: 'コンビニ 50円引き',
        expiresAt: DateTime.now().add(const Duration(hours: 12)),
        status: CouponStatus.active,
        distanceTier: '近い',
      ),
    ];

    final ownedCoupons = <Coupon>[
      Coupon(
        id: 'o1',
        title: 'ポイント交換クーポン',
        benefit: 'ドリンク無料（Sサイズ）',
        expiresAt: DateTime.now().add(const Duration(days: 7)),
        status: CouponStatus.owned,
        distanceTier: '交換',
      ),
      Coupon(
        id: 'o2',
        title: '期限切れテスト',
        benefit: 'お菓子 10%OFF',
        expiresAt: DateTime.now().subtract(const Duration(days: 1)),
        status: CouponStatus.expired,
        distanceTier: '—',
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('クーポン'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _SectionHeader(
            title: '配信中',
            subtitle: '距離に応じて内容が変わる想定',
          ),
          const SizedBox(height: 8),
          ...activeCoupons.map((c) => CouponCard(
                coupon: c,
                primaryActionLabel: '取得',
                onPrimaryAction: () {
                  // TODO: 取得処理（今は仮）
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('「${c.benefit}」を取得しました（仮）')),
                  );
                },
              )),
          const SizedBox(height: 18),
          _SectionHeader(
            title: '取得済み',
            subtitle: '使用・期限切れもここに出す',
          ),
          const SizedBox(height: 8),
          ...ownedCoupons.map((c) => CouponCard(
                coupon: c,
                primaryActionLabel: c.isExpired ? '期限切れ' : '使う',
                onPrimaryAction: c.isExpired
                    ? null
                    : () {
                        // TODO: 使用処理（今は仮）
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('「${c.benefit}」を使用しました（仮）')),
                        );
                      },
              )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// --- UI parts ---

class CouponCard extends StatelessWidget {
  final Coupon coupon;
  final String primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  const CouponCard({
    super.key,
    required this.coupon,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expiresText = _formatRemaining(coupon.expiresAt);
    final colorScheme = theme.colorScheme;
    final tierColor = _tierColor(coupon, colorScheme);
    final surface = coupon.isExpired
        ? colorScheme.surfaceVariant.withOpacity(0.7)
        : colorScheme.surface;
    final accent = coupon.isExpired
        ? colorScheme.outlineVariant
        : colorScheme.primaryContainer;

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
          color: coupon.isExpired
              ? colorScheme.outlineVariant
              : colorScheme.primary.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 14,
            top: 12,
            child: Icon(
              Icons.local_offer,
              size: 26,
              color: coupon.isExpired
                  ? colorScheme.outline
                  : colorScheme.primary.withOpacity(0.7),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 上段：タイトル + ステータス
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        coupon.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Badge(
                      text: coupon.distanceTier,
                      icon: Icons.near_me,
                      color: tierColor,
                      isMuted: coupon.isExpired,
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 特典（太字）
                Text(
                  coupon.benefit,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),

                // 期限
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: coupon.isExpired
                        ? colorScheme.errorContainer.withOpacity(0.2)
                        : colorScheme.secondaryContainer.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule,
                        size: 16,
                        color:
                            coupon.isExpired ? colorScheme.error : tierColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        coupon.isExpired ? '期限切れ' : '期限：$expiresText',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: coupon.isExpired
                              ? colorScheme.error
                              : colorScheme.onSecondaryContainer,
                          fontWeight:
                              coupon.isExpired ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 下段：ボタン
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // 詳細は将来 BottomSheet にしてもOK
                          showModalBottomSheet(
                            context: context,
                            showDragHandle: true,
                            builder: (_) => _CouponDetailSheet(coupon: coupon),
                          );
                        },
                        child: const Text('詳細'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: onPrimaryAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: coupon.isExpired
                              ? colorScheme.surfaceVariant
                              : colorScheme.primary,
                          foregroundColor: coupon.isExpired
                              ? colorScheme.onSurfaceVariant
                              : colorScheme.onPrimary,
                        ),
                        child: Text(primaryActionLabel),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponDetailSheet extends StatelessWidget {
  final Coupon coupon;
  const _CouponDetailSheet({required this.coupon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(coupon.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(coupon.benefit, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text('距離カテゴリ：${coupon.distanceTier}'),
          const SizedBox(height: 6),
          Text('有効期限：${coupon.expiresAt}'),
          const SizedBox(height: 18),
          const Text('※ここに利用条件（対象店舗・最低購入金額など）を追加できます。'),
        ],
      ),
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
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final bool isMuted;
  const _Badge({
    required this.text,
    required this.icon,
    required this.color,
    required this.isMuted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = isMuted ? theme.colorScheme.outlineVariant : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: chipColor.withOpacity(0.16),
        border: Border.all(color: chipColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipColor),
          const SizedBox(width: 6),
          Text(text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: chipColor,
              )),
        ],
      ),
    );
  }
}

/// --- Model (仮) ---

enum CouponStatus { active, owned, expired }

class Coupon {
  final String id;
  final String title;
  final String benefit;
  final DateTime expiresAt;
  final CouponStatus status;

  /// 「近い/遠い/交換」など、距離連動をUIに見せるためのラベル
  final String distanceTier;

  Coupon({
    required this.id,
    required this.title,
    required this.benefit,
    required this.expiresAt,
    required this.status,
    required this.distanceTier,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

String _formatRemaining(DateTime expiresAt) {
  final now = DateTime.now();
  final diff = expiresAt.difference(now);

  if (diff.isNegative) return '—';

  final days = diff.inDays;
  final hours = diff.inHours % 24;
  if (days >= 1) return 'あと${days}日 ${hours}時間';
  final minutes = diff.inMinutes % 60;
  if (diff.inHours >= 1) return 'あと${diff.inHours}時間 ${minutes}分';
  return 'あと${diff.inMinutes}分';
}

Color _tierColor(Coupon coupon, ColorScheme scheme) {
  if (coupon.isExpired) return scheme.outline;
  switch (coupon.distanceTier) {
    case '遠い':
      return scheme.primary;
    case '近い':
      return scheme.tertiary;
    case '交換':
      return scheme.secondary;
    default:
      return scheme.primary;
  }
}
