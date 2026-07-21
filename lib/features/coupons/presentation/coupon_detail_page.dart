import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/domain/store.dart';
import '../../stores/providers/store_providers.dart';
import '../../../core/domain/coupon.dart';
import '../providers/coupon_providers.dart';
import 'coupon_actions.dart';
import 'widgets/swipe_to_use.dart';

class CouponDetailPage extends ConsumerStatefulWidget {
  final Coupon coupon;
  const CouponDetailPage({super.key, required this.coupon});

  @override
  ConsumerState<CouponDetailPage> createState() => _CouponDetailPageState();
}

class _CouponDetailPageState extends ConsumerState<CouponDetailPage>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;

  /// この画面でスワイプ消込を完了したか。完了後は provider 反映を待たずに
  /// 「使用済み」表示へ倒し、CTA も無効状態のまま固定する。
  bool _redeemed = false;

  /// 消込確定時のカード演出（光の走り → ギフトのポップ → 使用済みスタンプ → ディム）。
  /// 0.0〜1.0 を約1秒で進め、4段階を短いタイムラインに収める。
  late final AnimationController _celebrate;

  @override
  void initState() {
    super.initState();
    _celebrate = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    // 既に使用済みのクーポンを開いた場合は、演出を再生せず最終状態を即表示する。
    if (widget.coupon.status == CouponStatus.used) {
      _celebrate.value = 1.0;
    }
    if (widget.coupon.isUsable) {
      _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _celebrate.dispose();
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
            _BenefitHero(
              benefit: coupon.benefit,
              used: _redeemed || coupon.status == CouponStatus.used,
              celebrate: _celebrate,
            ),
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
            const SectionLabel(label: '利用方法', padding: EdgeInsets.zero),
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
            const SectionLabel(label: 'クーポン情報', padding: EdgeInsets.zero),
            const SizedBox(height: 8),
            _InfoTable(coupon: coupon),
            const SizedBox(height: 28),
            // 消込後も同じ SwipeToUse を保持し、完了状態（チェック・バウンド）を
            // provider 反映の有無に関わらず保つ。
            if (coupon.isUsable || _redeemed) ...[
              SwipeToUse(
                label: '会計時にスワイプして消込',
                completedLabel: '消込完了 ✓',
                onCompleted: () => _redeem(context, ref),
              ),
              // モーダルで流れを止めず、CTA 直下に状態変化として確認を出す。
              _RedeemConfirmation(visible: _redeemed, celebrate: _celebrate),
            ] else
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
    final messenger = ScaffoldMessenger.of(context);
    // 失敗時は redeemCouponAndRefresh が rethrow し、SwipeToUse がスワイプを巻き戻す。
    await redeemCouponAndRefresh(ref, messenger, widget.coupon);
    if (!mounted) return;
    // 全画面モーダルではなく、その場の状態変化として「確定」を見せる。
    // SwipeToUse 側がチェックのバウンドと haptic を担い、カード演出はここで再生する。
    setState(() => _redeemed = true);
    _celebrate.forward(from: 0);
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

/// 特典カード。消込確定時に「光の走り → ギフトのポップ → 使用済みスタンプ →
/// カードのディム」を [celebrate] のタイムライン上で順に再生し、特典が使われたことを伝える。
class _BenefitHero extends StatelessWidget {
  final String benefit;
  final bool used;
  final Animation<double> celebrate;

  const _BenefitHero({
    required this.benefit,
    required this.used,
    required this.celebrate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: celebrate,
      builder: (context, _) {
        final t = celebrate.value;
        // ギフトのポップ（0.1〜0.5 で弾む）。
        final popT = ((t - 0.1) / 0.4).clamp(0.0, 1.0);
        final giftScale =
            used ? 0.6 + 0.4 * Curves.elasticOut.transform(popT) : 1.0;
        // 光の走り（前半のみ。終わると画面外へ抜けるため描画しない）。
        final sweepT = (t / 0.55).clamp(0.0, 1.0);
        final showSweep = used && t > 0.0 && t < 0.55;
        // 使用済みスタンプ／ディム（0.45〜1.0 でフェードイン）。
        final stampT =
            used ? Curves.easeOut.transform(((t - 0.45) / 0.55).clamp(0.0, 1.0)) : 0.0;

        return Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.accent, AppColors.accentAlt],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x3300A88F),
                    blurRadius: 24,
                    spreadRadius: -8,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Transform.scale(
                    scale: giftScale,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        used
                            ? Icons.redeem_rounded
                            : Icons.card_giftcard_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
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
            ),
            // カード内に収めるためのオーバーレイ群（光の走り・ディム・スタンプ）。
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: IgnorePointer(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 落ち着いた色へ少しだけ沈める。
                      if (stampT > 0)
                        ColoredBox(
                          color: const Color(0xFF0D2A28)
                              .withValues(alpha: 0.28 * stampT),
                        ),
                      if (showSweep) _LightSweep(progress: sweepT),
                      if (stampT > 0)
                        Center(child: _UsedStamp(progress: stampT)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 特典カードを横切る一筋の光。斜めの明るい帯を左から右へ走らせる。
class _LightSweep extends StatelessWidget {
  final double progress; // 0..1
  const _LightSweep({required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final dx = -w * 0.6 + (w * 1.6) * progress;
        // 中央で最も明るく、両端でフェードして自然に抜ける。
        final intensity =
            (1 - (progress - 0.5).abs() * 2).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: Transform.rotate(
            angle: -0.35,
            child: Container(
              width: w * 0.32,
              height: constraints.maxHeight * 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.42 * intensity),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 「使用済み」スタンプ。半透明の枠付きで斜めに、弾むように現れる。
class _UsedStamp extends StatelessWidget {
  final double progress; // 0..1
  const _UsedStamp({required this.progress});

  @override
  Widget build(BuildContext context) {
    // 少し大きめから定位置へ。
    final scale = 1.3 - 0.3 * progress;
    return Opacity(
      opacity: progress,
      child: Transform.rotate(
        angle: -0.21,
        child: Transform.scale(
          scale: scale,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 2.5,
              ),
            ),
            child: Text(
              '使用済み',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CTA 直下に出す軽い確認表示。完了演出の後半でフェードアップする。
class _RedeemConfirmation extends StatelessWidget {
  final bool visible;
  final Animation<double> celebrate;
  const _RedeemConfirmation({required this.visible, required this.celebrate});

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: celebrate,
      builder: (context, _) {
        final t = ((celebrate.value - 0.5) / 0.5).clamp(0.0, 1.0);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 18, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'クーポンを使用しました',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    final icon = isUsable ? Icons.schedule_rounded : Icons.event_busy_rounded;
    final label = isUsable
        ? '残り${formatRemainingCompact(coupon.expiresAt.difference(DateTime.now()))}'
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
            '${formatDate(coupon.expiresAt)}まで',
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
            _row(context, '発行日時', formatDateTime(coupon.issuedAt)),
            const SizedBox(height: 8),
            _row(context, '有効期限', formatDateTime(coupon.expiresAt)),
            if (coupon.usedAt != null) ...[
              const SizedBox(height: 8),
              _row(context, '使用日時', formatDateTime(coupon.usedAt!)),
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


// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
