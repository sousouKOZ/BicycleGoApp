import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_decoration.dart';
import '../../../../core/utils/formatters.dart';

/// 画面下部の進捗バー（到着時刻・残り時間・残り距離）と終了/音声トグル。
class NavBottomBar extends StatelessWidget {
  final DateTime eta;
  final int remainingSeconds;
  final double remainingMeters;
  final bool voiceEnabled;
  final VoidCallback onToggleVoice;
  final VoidCallback onExit;

  const NavBottomBar({
    super.key,
    required this.eta,
    required this.remainingSeconds,
    required this.remainingMeters,
    required this.voiceEnabled,
    required this.onToggleVoice,
    required this.onExit,
  });

  String get _remainingLabel {
    final minutes = (remainingSeconds / 60).round();
    if (minutes < 1) return 'まもなく';
    if (minutes < 60) return '$minutes分';
    return '${minutes ~/ 60}時間${minutes % 60}分';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: GlassDecoration.light(context, radius: 22),
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _remainingLabel,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.accent,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      formatDistanceMeters(remainingMeters),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatTimeHm(eta)} 到着予定',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: context.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: voiceEnabled ? '音声案内をオフ' : '音声案内をオン',
            onPressed: onToggleVoice,
            icon: Icon(
              voiceEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              color: voiceEnabled ? AppColors.accent : context.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          FilledButton(
            onPressed: onExit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '終了',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
