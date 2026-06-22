import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_decoration.dart';
import '../../providers/map_filter_providers.dart';

/// 地図上部の絞り込みチップ列。状態は [mapFilterProvider] と直結。
class MapFilterBar extends ConsumerWidget {
  const MapFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(mapFilterProvider);
    final notifier = ref.read(mapFilterProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChipItem(
            icon: Icons.event_available_rounded,
            label: '空きのみ',
            selected: filter.availableOnly,
            onTap: () => notifier.state =
                filter.copyWith(availableOnly: !filter.availableOnly),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            icon: Icons.local_offer_rounded,
            label: 'クーポンあり',
            selected: filter.couponOnly,
            onTap: () => notifier.state =
                filter.copyWith(couponOnly: !filter.couponOnly),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            icon: Icons.schedule_rounded,
            label: '5分以内',
            selected: filter.within5MinutesOnly,
            onTap: () => notifier.state = filter.copyWith(
                within5MinutesOnly: !filter.within5MinutesOnly),
          ),
          const SizedBox(width: 8),
          _FilterChipItem(
            icon: Icons.star_rounded,
            label: 'お気に入り',
            selected: filter.favoriteOnly,
            onTap: () => notifier.state =
                filter.copyWith(favoriteOnly: !filter.favoriteOnly),
          ),
        ],
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChipItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: selected
          ? BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : GlassDecoration.pill(context),
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.accent.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: selected ? Colors.white : AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: selected ? Colors.white : context.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
