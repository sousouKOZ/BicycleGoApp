import 'package:flutter/material.dart';

import 'app_colors.dart';

/// BackdropFilterを使わない"ガラス風"のBoxDecoration集。
/// 半透明塗り + 細い白縁 + 柔らかい影で軽量にガラス感を再現する。
class GlassDecoration {
  GlassDecoration._();

  /// 明るい地（地図の上、白背景の上）で使う標準ガラス。
  static BoxDecoration light({
    double radius = 20,
    double opacity = 0.88,
  }) {
    return BoxDecoration(
      color: AppColors.surface.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A1A1F36),
          blurRadius: 24,
          spreadRadius: -8,
          offset: Offset(0, 10),
        ),
      ],
    );
  }

  /// ピル型（丸括弧状のトグル、チップなど）。
  static BoxDecoration pill({double opacity = 0.92}) {
    return BoxDecoration(
      color: AppColors.surface.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          blurRadius: 16,
          spreadRadius: -4,
          offset: Offset(0, 6),
        ),
      ],
    );
  }

  /// 強調カード（クーポン・CTAなど）。ほのかなグラデを持つ。
  static BoxDecoration accentCard({double radius = 22}) {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFF0F4FF),
        ],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1F2E7CF6),
          blurRadius: 30,
          spreadRadius: -10,
          offset: Offset(0, 14),
        ),
      ],
    );
  }
}
