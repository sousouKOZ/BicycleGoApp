import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/navigation_state.dart';

/// 経路を外れたときのバナー。リルート中はスピナー、失敗時は再試行を出す。
class OffRouteBanner extends StatelessWidget {
  final NavPhase phase;
  final String? error;
  final VoidCallback onRetry;

  const OffRouteBanner({
    super.key,
    required this.phase,
    required this.error,
    required this.onRetry,
  });

  bool get _isRerouting => phase == NavPhase.rerouting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _isRerouting ? AppColors.navigation : AppColors.warning;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          if (_isRerouting)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          else
            const Icon(Icons.warning_amber_rounded,
                size: 20, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isRerouting
                  ? 'ルートを外れました。再検索しています…'
                  : (error ?? 'ルートを外れています'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (!_isRerouting)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const Text(
                '再検索',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
