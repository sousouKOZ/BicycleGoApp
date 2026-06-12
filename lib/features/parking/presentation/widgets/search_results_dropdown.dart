import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/domain/parking_lot.dart';
import '../../../../core/domain/store.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_decoration.dart';
import '../../../../core/theme/usage_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/geo.dart';
import '../../providers/recommendation_providers.dart';
import '../../providers/sort_mode_providers.dart';

/// 検索中に表示する駐輪場候補のドロップダウン。
/// 並び替え（距離順/おすすめ順）トグルを内包する。
class SearchResultsDropdown extends ConsumerWidget {
  final String query;
  final List<ParkingLot> allLots;
  final List<ParkingLot> filteredLots;
  final LatLng? currentLocation;
  final ValueChanged<ParkingLot> onTap;

  const SearchResultsDropdown({
    super.key,
    required this.query,
    required this.allLots,
    required this.filteredLots,
    required this.currentLocation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final recommendedStoresAsync = currentLocation != null
        ? ref.watch(recommendedStoresProvider(
            roundLocationForRecommendation(currentLocation!),
          ))
        : const AsyncValue.data(<Store>[]);
    final recommendedStores =
        recommendedStoresAsync.asData?.value ?? const <Store>[];

    final sortMode = ref.watch(parkingSortModeProvider);

    final source = query.isEmpty ? allLots : filteredLots;
    final recommendations = <String, ParkingRecommendation>{
      for (final p in source)
        p.id: computeRecommendation(
          parking: p,
          recommendedStores: recommendedStores,
          userLocation: currentLocation,
        ),
    };
    final sorted = [...source];
    if (sortMode == ParkingSortMode.recommend) {
      sorted.sort((a, b) =>
          recommendations[b.id]!.score.compareTo(recommendations[a.id]!.score));
    } else if (currentLocation != null) {
      sorted.sort((a, b) => Geo.haversineMeters(currentLocation!, a.position)
          .compareTo(Geo.haversineMeters(currentLocation!, b.position)));
    }

    if (sorted.isEmpty) {
      return Container(
        decoration: GlassDecoration.light(context, radius: 16),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.search_off_rounded,
                size: 18, color: context.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '「$query」に該当する駐輪場はありません',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: GlassDecoration.light(context, radius: 16),
      clipBehavior: Clip.antiAlias,
      // Flexible 親が残り高さを渡すので、ここは "それ以上は伸ばさない" という上限として機能する。
      constraints: const BoxConstraints(maxHeight: 360),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SortToggleRow(
              mode: sortMode,
              onChanged: (m) =>
                  ref.read(parkingSortModeProvider.notifier).state = m,
            ),
            Divider(
              height: 1,
              color: context.subtleBorder,
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: sorted.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: context.subtleBorder,
                  indent: 62,
                ),
                itemBuilder: (_, i) {
                  final p = sorted[i];
                  final rec = recommendations[p.id]!;
                  final usageColor = p.usageLevel.color;
                  final distance = currentLocation == null
                      ? null
                      : Geo.haversineMeters(currentLocation!, p.position);
                  final distanceLabel =
                      distance == null ? null : formatDistanceMeters(distance);
                  return InkWell(
                    onTap: () => onTap(p),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: usageColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.local_parking_rounded,
                                size: 20, color: usageColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        p.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (rec.isRecommended) ...[
                                      const SizedBox(width: 6),
                                      _RecommendBadge(
                                        bonusPercent: rec.bonusPointsPercent,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      '空き${p.available}/${p.capacity}',
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: usageColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      ' ・ 稼働${p.usageRatePercent}%'
                                      '${distanceLabel != null ? ' ・ $distanceLabel' : ''}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.north_east_rounded,
                              size: 16, color: context.textSecondary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortToggleRow extends StatelessWidget {
  final ParkingSortMode mode;
  final ValueChanged<ParkingSortMode> onChanged;
  const _SortToggleRow({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Icon(Icons.sort_rounded, size: 16, color: context.textSecondary),
          const SizedBox(width: 6),
          Text(
            '並び替え',
            style: theme.textTheme.labelMedium,
          ),
          const Spacer(),
          _SortToggleButton(
            label: '距離順',
            selected: mode == ParkingSortMode.distance,
            onTap: () => onChanged(ParkingSortMode.distance),
          ),
          const SizedBox(width: 6),
          _SortToggleButton(
            label: 'おすすめ順',
            selected: mode == ParkingSortMode.recommend,
            onTap: () => onChanged(ParkingSortMode.recommend),
          ),
        ],
      ),
    );
  }
}

class _SortToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SortToggleButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? AppColors.accent : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? Colors.transparent : context.subtleBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: selected ? Colors.white : context.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecommendBadge extends StatelessWidget {
  final int bonusPercent;
  const _RecommendBadge({required this.bonusPercent});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.accent, AppColors.accentAlt],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome_rounded, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            bonusPercent > 0 ? 'おすすめ +$bonusPercent%' : 'おすすめ',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
