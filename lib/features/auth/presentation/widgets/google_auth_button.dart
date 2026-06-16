import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Google でサインイン / 連携するための共通ボタン（ブラウザ OAuth を起動）。
///
/// タップで [onPressed] がカスタムタブを開くだけで、サインイン完了は
/// onAuthStateChange 側で処理される。`busy` 中は無効化してスピナーを出す。
class GoogleAuthButton extends StatelessWidget {
  final bool busy;
  final String label;
  final VoidCallback onPressed;

  const GoogleAuthButton({
    super.key,
    required this.busy,
    required this.onPressed,
    this.label = 'Google で続ける',
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: busy ? null : onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
      ),
      child: busy
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _GoogleGlyph(),
                const SizedBox(width: 12),
                Text(label),
              ],
            ),
    );
  }
}

/// 簡易の Google "G" マーク。
/// NOTE: 厳密なブランドガイドラインに沿う場合は公式ロゴ（4色 G）のアセットに差し替える。
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.onSurfaceSecondary.withValues(alpha: 0.2)),
      ),
      child: const Text(
        'G',
        style: TextStyle(
          // Google ブルー。
          color: Color(0xFF4285F4),
          fontWeight: FontWeight.w900,
          fontSize: 14,
          height: 1.0,
        ),
      ),
    );
  }
}
