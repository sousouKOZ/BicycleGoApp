import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// クーポン券の地色。ライトテーマでは状態色を薄く混ぜ、チケットらしさと
/// 一覧での判別しやすさを両立する。
Color couponCardColor(
  BuildContext context, {
  Color tint = AppColors.coupon,
  bool dimmed = false,
}) {
  final theme = Theme.of(context);
  final alpha = dimmed ? 0.04 : 0.08;
  final base = theme.brightness == Brightness.dark
      ? theme.colorScheme.surface
      : Colors.white;
  return Color.alphaBlend(tint.withValues(alpha: alpha), base);
}

/// 紙の粒状感（グレイン）を薄く重ねるペインタ。画像アセット不要・固定シード。
class PaperTexturePainter extends CustomPainter {
  final bool dark;
  const PaperTexturePainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final area = size.width * size.height;
    final count = (area / 110).clamp(0, 220).toInt();
    for (var i = 0; i < count; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final isDark = rnd.nextBool();
      final alpha = isDark ? 0.035 : 0.06;
      final paint = Paint()
        ..color = (isDark ? Colors.black : Colors.white)
            .withValues(alpha: dark ? alpha * 0.6 : alpha);
      canvas.drawCircle(Offset(dx, dy), rnd.nextDouble() * 0.7 + 0.3, paint);
    }
  }

  @override
  bool shouldRepaint(PaperTexturePainter old) => old.dark != dark;
}

/// 横のミシン目：両端に背景色の半円（切り欠き）+ 中央に破線。
class PerforationPainter extends CustomPainter {
  final Color notchColor;
  final Color dashColor;
  const PerforationPainter({required this.notchColor, required this.dashColor});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final r = size.height / 2;
    final notch = Paint()..color = notchColor;
    canvas.drawCircle(Offset(0, cy), r, notch);
    canvas.drawCircle(Offset(size.width, cy), r, notch);

    final dash = Paint()
      ..color = dashColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const dashW = 5.0;
    const gap = 4.0;
    var x = r + 6;
    final endX = size.width - r - 6;
    while (x < endX) {
      canvas.drawLine(Offset(x, cy), Offset(x + dashW, cy), dash);
      x += dashW + gap;
    }
  }

  @override
  bool shouldRepaint(PerforationPainter old) =>
      old.notchColor != notchColor || old.dashColor != dashColor;
}

/// 縦のミシン目：上下端に背景色の半円（切り欠き）+ 縦の破線。
class VerticalPerforationPainter extends CustomPainter {
  final Color notchColor;
  final Color dashColor;
  const VerticalPerforationPainter({
    required this.notchColor,
    required this.dashColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final r = size.width / 2;
    final notch = Paint()..color = notchColor;
    canvas.drawCircle(Offset(cx, 0), r, notch);
    canvas.drawCircle(Offset(cx, size.height), r, notch);

    final dash = Paint()
      ..color = dashColor
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const dashH = 5.0;
    const gap = 4.0;
    var y = r + 6;
    final endY = size.height - r - 6;
    while (y < endY) {
      canvas.drawLine(Offset(cx, y), Offset(cx, y + dashH), dash);
      y += dashH + gap;
    }
  }

  @override
  bool shouldRepaint(VerticalPerforationPainter old) =>
      old.notchColor != notchColor || old.dashColor != dashColor;
}

/// 左に縦ミシン目の半券を持つコンパクトなチケット。配信中クーポンや
/// マイページのサマリ表示で使う。
class MiniCouponTicket extends StatelessWidget {
  final IconData stubIcon;
  final String stubLabel;
  final Color stubColor;
  final String benefit;
  final String subtitle;
  final VoidCallback onTap;
  final bool dimmed;
  final Color? tintColor;

  const MiniCouponTicket({
    super.key,
    required this.stubIcon,
    required this.stubLabel,
    required this.stubColor,
    required this.benefit,
    required this.subtitle,
    required this.onTap,
    this.dimmed = false,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pageColor = theme.scaffoldBackgroundColor;
    final benefitColor = dimmed ? context.textSecondary : context.textPrimary;
    final cardColor =
        couponCardColor(context, tint: tintColor ?? stubColor, dimmed: dimmed);

    return Opacity(
      opacity: dimmed ? 0.7 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: stubColor.withValues(alpha: dimmed ? 0.03 : 0.08),
              blurRadius: 14,
              spreadRadius: -4,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: PaperTexturePainter(
                    dark: theme.brightness == Brightness.dark,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 54,
                          child: ColoredBox(
                            color: stubColor.withValues(
                                alpha: dimmed ? 0.06 : 0.1),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(stubIcon, size: 16, color: stubColor),
                                  const SizedBox(height: 4),
                                  Text(
                                    stubLabel,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: stubColor,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 14,
                          child: CustomPaint(
                            painter: VerticalPerforationPainter(
                              notchColor: pageColor,
                              dashColor: context.subtleBorder,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 14, 14, 14),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  benefit,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                    height: 1.2,
                                    color: benefitColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style:
                                            theme.textTheme.bodySmall?.copyWith(
                                          color: context.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.chevron_right_rounded,
                                        size: 18, color: context.textSecondary),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
