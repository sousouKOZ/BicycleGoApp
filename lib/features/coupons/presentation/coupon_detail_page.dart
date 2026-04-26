import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
import '../../stores/domain/store.dart';
import '../../stores/providers/store_providers.dart';
import '../../user/providers/user_providers.dart';
import '../domain/coupon.dart';
import '../providers/coupon_providers.dart';
import 'widgets/swipe_to_use.dart';

class CouponDetailPage extends ConsumerStatefulWidget {
  final Coupon coupon;
  const CouponDetailPage({super.key, required this.coupon});

  @override
  ConsumerState<CouponDetailPage> createState() => _CouponDetailPageState();
}

class _CouponDetailPageState extends ConsumerState<CouponDetailPage> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.coupon.isUsable) {
      _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 一覧やマイページなど他の画面で消込された場合に追従できるよう、
    // userCouponsProvider から最新状態を取得する。フォールバックは constructor のスナップショット。
    final asyncCoupons = ref.watch(userCouponsProvider);
    final latest = asyncCoupons.asData?.value ?? const <Coupon>[];
    Coupon coupon = widget.coupon;
    for (final c in latest) {
      if (c.id == widget.coupon.id) {
        coupon = c;
        break;
      }
    }

    final stores = ref.watch(storesProvider).asData?.value ?? const <Store>[];
    Store? store;
    for (final s in stores) {
      if (s.id == coupon.storeId) {
        store = s;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('クーポン詳細'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _StatusBadgeRow(coupon: coupon),
            const SizedBox(height: 14),
            Text(
              coupon.storeName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              coupon.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            _BenefitHero(benefit: coupon.benefit),
            const SizedBox(height: 16),
            _ExpiryCountdown(coupon: coupon),
            const SizedBox(height: 18),
            if (store != null) ...[
              Builder(
                builder: (_) {
                  final s = store!;
                  return _ActionCard(
                    icon: Icons.map_outlined,
                    title: '店舗を地図で開く',
                    subtitle:
                        '${s.category.label} · おすすめ度 ${(s.recommendWeight * 100).round()}',
                    onTap: () => _openStoreInMaps(s),
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
            const _SectionLabel(label: '利用方法'),
            const SizedBox(height: 8),
            _NumberedStep(
              index: 1,
              text: '店舗のレジでこの画面を提示してください',
            ),
            _NumberedStep(
              index: 2,
              text: '会計時にスタッフ立ち会いのもとで下のスワイプで消込',
            ),
            _NumberedStep(
              index: 3,
              text: '消込後は元に戻せません。再発行もできません',
            ),
            const SizedBox(height: 24),
            const _SectionLabel(label: 'クーポン情報'),
            const SizedBox(height: 8),
            _InfoTable(coupon: coupon),
            const SizedBox(height: 28),
            if (coupon.isUsable)
              SwipeToUse(
                label: '会計時にスワイプして消込',
                completedLabel: '消込完了 ✓',
                onCompleted: () => _redeem(context, ref),
              )
            else
              _DisabledState(coupon: coupon),
          ],
        ),
      ),
    );
  }

  Future<void> _openStoreInMaps(Store store) async {
    final lat = store.position.latitude;
    final lng = store.position.longitude;
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _redeem(BuildContext context, WidgetRef ref) async {
    final api = ref.read(apiClientProvider);
    final userId = ref.read(currentUserIdProvider);
    await api.redeemCoupon(userId: userId, couponId: widget.coupon.id);
    ref.invalidate(userCouponsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.coupon.storeName}で使用しました')),
    );
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!context.mounted) return;
    Navigator.of(context).maybePop();
  }
}

class _StatusBadgeRow extends StatelessWidget {
  final Coupon coupon;
  const _StatusBadgeRow({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = _statusSpec(coupon);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: spec.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(spec.icon, size: 12, color: spec.color),
              const SizedBox(width: 4),
              Text(
                spec.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: spec.color,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: context.subtleBorder,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${coupon.distanceTier.label}駐輪場で発行',
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _BenefitHero extends StatelessWidget {
  final String benefit;
  const _BenefitHero({required this.benefit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E7CF6), Color(0xFF7C5CFF)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332E7CF6),
            blurRadius: 24,
            spreadRadius: -8,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.card_giftcard_rounded,
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '特典',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  benefit,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.2,
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

class _ExpiryCountdown extends StatelessWidget {
  final Coupon coupon;
  const _ExpiryCountdown({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUsable = coupon.isUsable;
    final isUsed = coupon.status == CouponStatus.used;
    if (isUsed) return const SizedBox.shrink();

    final color = isUsable ? AppColors.success : AppColors.danger;
    final icon =
        isUsable ? Icons.schedule_rounded : Icons.event_busy_rounded;
    final label = isUsable
        ? '残り${_formatRemaining(coupon.expiresAt)}'
        : '期限切れ';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          Text(
            _formatDate(coupon.expiresAt) + 'まで',
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: GlassDecoration.light(context, radius: 16),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: AppColors.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.textSecondary,
                          )),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: context.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  final int index;
  final String text;
  const _NumberedStep({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTable extends StatelessWidget {
  final Coupon coupon;
  const _InfoTable({required this.coupon});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: GlassDecoration.light(context, radius: 16),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _row(context, '発行日時', _formatDateTime(coupon.issuedAt)),
            const SizedBox(height: 8),
            _row(context, '有効期限', _formatDateTime(coupon.expiresAt)),
            if (coupon.usedAt != null) ...[
              const SizedBox(height: 8),
              _row(context, '使用日時', _formatDateTime(coupon.usedAt!)),
            ],
            const SizedBox(height: 8),
            _row(context, 'クーポンID', coupon.id),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _DisabledState extends StatelessWidget {
  final Coupon coupon;
  const _DisabledState({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUsed = coupon.status == CouponStatus.used;
    final color = isUsed ? AppColors.success : AppColors.danger;
    final icon = isUsed ? Icons.check_circle_rounded : Icons.cancel_rounded;
    final label = isUsed ? '使用済みのクーポンです' : '有効期限を過ぎています';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSpec {
  final IconData icon;
  final String label;
  final Color color;
  const _StatusSpec(this.icon, this.label, this.color);
}

_StatusSpec _statusSpec(Coupon coupon) {
  if (coupon.status == CouponStatus.used) {
    return const _StatusSpec(
      Icons.check_circle_outline_rounded,
      '使用済み',
      AppColors.onSurfaceSecondary,
    );
  }
  if (!coupon.isUsable) {
    return const _StatusSpec(
      Icons.event_busy_rounded,
      '期限切れ',
      AppColors.danger,
    );
  }
  return const _StatusSpec(
    Icons.local_offer_rounded,
    '利用可能',
    AppColors.success,
  );
}

String _formatRemaining(DateTime expiresAt) {
  final diff = expiresAt.difference(DateTime.now());
  if (diff.isNegative) return '0分';
  final days = diff.inDays;
  final hours = diff.inHours % 24;
  if (days >= 1) return '$days日 $hours時間';
  final minutes = diff.inMinutes % 60;
  if (diff.inHours >= 1) return '${diff.inHours}時間 $minutes分';
  return '${diff.inMinutes}分';
}

String _formatDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}/${two(d.month)}/${two(d.day)}';
}

String _formatDateTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}/${two(d.month)}/${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
