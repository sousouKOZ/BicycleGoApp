import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// クーポン消込完了時に全画面でかぶせる成功オーバーレイ。
///
/// 中央のチェックが円とともに弾むように現れ、店舗名・特典を表示する。
/// 約 [holdDuration] 表示したのち自動で閉じて呼び出し元へ戻る。
/// 表示の瞬間にハプティクスを発火し、レジ提示時に「使用済み」が一目で伝わる演出。
Future<void> showCouponRedeemedOverlay(
  BuildContext context, {
  required String storeName,
  required String benefit,
  Duration holdDuration = const Duration(milliseconds: 1500),
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: '使用完了',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, __, ___) => _CouponRedeemedOverlay(
      storeName: storeName,
      benefit: benefit,
      holdDuration: holdDuration,
    ),
    transitionBuilder: (_, animation, __, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class _CouponRedeemedOverlay extends StatefulWidget {
  final String storeName;
  final String benefit;
  final Duration holdDuration;

  const _CouponRedeemedOverlay({
    required this.storeName,
    required this.benefit,
    required this.holdDuration,
  });

  @override
  State<_CouponRedeemedOverlay> createState() => _CouponRedeemedOverlayState();
}

class _CouponRedeemedOverlayState extends State<_CouponRedeemedOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _badgeScale;
  late final Animation<double> _ringProgress;
  late final Animation<double> _textProgress;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // チェックバッジが弾むように現れる（案A「広がりながら描画 → 弾む」）。
    _badgeScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );
    // バッジ背後で広がって消えるリング。
    _ringProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
    );
    // 店舗名・特典は少し遅れてフェードアップ。
    _textProgress = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticFeedback.heavyImpact();
      _controller.forward();
    });
    // 一定時間見せてから自動で閉じる。
    Future<void>.delayed(widget.holdDuration, _dismiss);
  }

  void _dismiss() {
    if (_dismissed || !mounted) return;
    _dismissed = true;
    Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        // タップで即座に閉じられるようにしておく。
        onTap: _dismiss,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size.square(160),
                          painter: _RingPainter(progress: _ringProgress.value),
                        ),
                        Transform.scale(
                          scale: _badgeScale.value,
                          child: _CheckBadge(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Opacity(
                    opacity: _textProgress.value.clamp(0.0, 1.0),
                    child: Transform.translate(
                      offset: Offset(0, 12 * (1 - _textProgress.value)),
                      child: Column(
                        children: [
                          Text(
                            '使用しました',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Text(
                              widget.benefit,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.storeName,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CheckBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.success, AppColors.accent],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.success.withValues(alpha: 0.5),
            blurRadius: 28,
            spreadRadius: -4,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.check_rounded, color: Colors.white, size: 56),
    );
  }
}

/// チェックバッジの背後で広がりながら薄れていくリング。
class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final radius = 36 + (maxRadius - 36) * progress;
    final fade = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * fade + 1
      ..color = AppColors.success.withValues(alpha: 0.45 * fade);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
