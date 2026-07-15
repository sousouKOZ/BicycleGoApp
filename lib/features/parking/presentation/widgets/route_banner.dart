import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_decoration.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/directions_route.dart';

/// 表示中ルートの距離・所要時間を出すバナー。ここがナビ開始の入口も兼ねる。
class RouteBanner extends StatelessWidget {
  final DirectionsRoute route;
  final VoidCallback onClose;
  final VoidCallback onStartNavigation;

  const RouteBanner({
    super.key,
    required this.route,
    required this.onClose,
    required this.onStartNavigation,
  });

  String get _distanceLabel =>
      formatDistanceMeters(route.distanceMeters.toDouble());

  String get _durationLabel {
    final minutes = (route.durationSeconds / 60).round();
    if (minutes < 60) return '約$minutes分';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '約$h時間' : '約$h時間$m分';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: GlassDecoration.light(context, radius: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.directions_bike_rounded,
                    size: 18, color: AppColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      route.parkingName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.route_rounded,
                            size: 14, color: context.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _distanceLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.schedule_rounded,
                            size: 14, color: context.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _durationLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'ルートを消す',
                onPressed: onClose,
                icon: Icon(Icons.close_rounded,
                    size: 18, color: context.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStartNavigation,
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('ナビ開始'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.navigation,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
