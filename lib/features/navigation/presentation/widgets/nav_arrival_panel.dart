import 'package:flutter/material.dart';

import '../../../../core/domain/parking_lot.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_decoration.dart';

/// 到着時に下部へ出すパネル。ナビの出口をそのまま駐輪フローの入口にする。
class NavArrivalPanel extends StatelessWidget {
  final ParkingLot parking;

  /// 既に他の駐輪を計測中なら認証させない（サーバ側も already_active で弾く）。
  final bool hasActiveSession;
  final bool authInProgress;
  final VoidCallback onStartParking;
  final VoidCallback onClose;

  const NavArrivalPanel({
    super.key,
    required this.parking,
    required this.hasActiveSession,
    required this.authInProgress,
    required this.onStartParking,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: GlassDecoration.light(context, radius: 22),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.sports_score_rounded,
                    size: 20, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '到着しました',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      parking.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'ナビを閉じる',
                onPressed: authInProgress ? null : onClose,
                icon: Icon(Icons.close_rounded, color: context.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  hasActiveSession || authInProgress ? null : onStartParking,
              icon: authInProgress
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      hasActiveSession
                          ? Icons.directions_bike_rounded
                          : Icons.nfc_rounded,
                      size: 20,
                    ),
              label: Text(
                hasActiveSession ? '他の駐輪を計測中' : 'ここに駐輪する（タッチで計測開始）',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
