import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/usage_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/utils/geo.dart';
import '../../../core/domain/store.dart';
import '../../stores/presentation/store_preview_sheet.dart';
import '../data/directions_service.dart';
import '../domain/parking_lot_filter.dart';
import '../providers/favorite_providers.dart';
import '../providers/recommendation_providers.dart';
import '../providers/route_providers.dart';
import '../../nfc/presentation/nfc_lock_sheet.dart';
import '../../points/providers/points_providers.dart';
import '../../sessions/presentation/session_timer_page.dart';
import '../data/parking_mock_data.dart';
import '../../../core/domain/parking_lot.dart';
import '../../../core/domain/parking_session.dart';
import '../providers/parking_providers.dart';

class ParkingDetailSheet extends ConsumerWidget {
  final ParkingLot parking;
  const ParkingDetailSheet({super.key, required this.parking});

  Future<void> _fetchRoute(
    BuildContext context,
    WidgetRef ref,
    ScaffoldMessengerState messenger,
    LatLng? cachedLocation,
  ) async {
    ref.read(routeLoadingProvider.notifier).state = true;
    try {
      // 起動時の座標は古い・屋内取得で不正確な場合があるため、
      // ルート取得直前に新しい fix を取り直す。
      // 8秒で取れなければキャッシュにフォールバック。
      LatLng? origin;
      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
        origin = LatLng(pos.latitude, pos.longitude);
        // フレッシュな座標を全体プロバイダにも反映（地図側の表示も更新）。
        ref.read(currentLocationProvider.notifier).state = origin;
      } catch (_) {
        origin = cachedLocation;
      }

      if (origin == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              '現在地が取得できませんでした。屋外で位置情報が取れる場所で再度お試しください。',
            ),
            duration: Duration(seconds: 6),
          ),
        );
        return;
      }

      final service = ref.read(directionsServiceProvider);
      final route = await service.fetch(
        origin: origin,
        parking: parking,
      );
      ref.read(activeRouteProvider.notifier).state = route;
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    } on DirectionsException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('ルート取得失敗: ${e.message}'),
          duration: const Duration(seconds: 8),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('ルート取得に失敗しました（$e）'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      ref.read(routeLoadingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = parking.usageRatePercent / 100.0;
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final currentLocation = ref.watch(currentLocationProvider);
    // ルートを取得済みなら同じ値（自転車経路の実距離・実所要時間）を使い、
    // 上部の _RouteBanner と完全に一致させる。
    // 未取得時は直線距離 + 自転車速度（250m/分 ≒ 15km/h）で見積もり。
    final activeRoute = ref.watch(activeRouteProvider);
    final useRoute =
        activeRoute != null && activeRoute.parkingLotId == parking.id;
    final distanceMeters = useRoute
        ? activeRoute.distanceMeters.toDouble()
        : currentLocation == null
            ? null
            : Geo.haversineMeters(currentLocation, parking.position);
    final cyclingMinutes = useRoute
        ? (activeRoute.durationSeconds / 60).round()
        : distanceMeters == null
            ? null
            : (distanceMeters / bikeMetersPerMinute).round().clamp(1, 999);
    final usageColor = parking.usageLevel.color;
    final recommendedStoresAsync = ref.watch(recommendedStoresProvider(
      roundLocationForRecommendation(parking.position),
    ));
    final recommendedStores =
        recommendedStoresAsync.asData?.value ?? const <Store>[];

    final recommendation = computeRecommendation(
      parking: parking,
      recommendedStores: recommendedStores,
      userLocation: currentLocation,
    );

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '駐輪場',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        parking.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                _FavoriteButton(parkingId: parking.id),
                const SizedBox(width: 8),
                _UsageBadge(
                  percent: parking.usageRatePercent,
                  color: usageColor,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: context.subtleBorder,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: '空き',
                          value: '${parking.available}',
                          emphasis: true,
                          color: usageColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 1,
                        height: 36,
                        color: context.subtleBorder,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Stat(
                          label: '収容',
                          value: '${parking.capacity}',
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 1,
                        height: 36,
                        color: context.subtleBorder,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _Stat(
                          label: '料金/日',
                          value: '¥${parking.priceYenPerDay}',
                          color: context.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: usage,
                      minHeight: 8,
                      color: usageColor,
                      backgroundColor: usageColor.withValues(alpha: 0.15),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  icon: Icons.update_rounded,
                  label: '更新 ${formatTimeHm(parking.updatedAt)}',
                ),
                if (distanceMeters == null)
                  _MetaChip(
                    icon: Icons.location_searching,
                    label: '距離 取得中',
                  )
                else ...[
                  _MetaChip(
                    icon: Icons.place_outlined,
                    // 上部の RouteBanner と表記を揃える（1km 未満は m、それ以上は km）。
                    label: '約${formatDistanceMeters(distanceMeters)}',
                  ),
                  _MetaChip(
                    icon: Icons.directions_bike_rounded,
                    label: '自転車 約$cyclingMinutes分',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            _TimeAvailabilitySection(parking: parking),
            if (recommendation.nearbyStores.isNotEmpty) ...[
              const SizedBox(height: 18),
              _NearbyCouponsSection(
                recommendation: recommendation,
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Consumer(
                    builder: (context, ref, _) {
                      final loading = ref.watch(routeLoadingProvider);
                      return OutlinedButton.icon(
                        onPressed: loading
                            ? null
                            : () => _fetchRoute(
                                  context,
                                  ref,
                                  messenger,
                                  currentLocation,
                                ),
                        icon: loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.directions_rounded, size: 18),
                        label: Text(
                          loading ? 'ルート取得中' : '経路を見る',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(
                            color: context.subtleBorder,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final device = mockDevices.firstWhere(
                        (d) => d.parkingLotId == parking.id,
                        orElse: () => mockDevices.first,
                      );
                      final navigator = Navigator.of(context);
                      final session =
                          await showAppBottomSheet<ParkingSession?>(
                        context,
                        builder: (_) => NfcLockSheet(
                          parkingId: parking.id,
                          parkingName: parking.name,
                          deviceId: device.id,
                        ),
                      );
                      if (session == null) {
                        return;
                      }
                      // 付与はサーバ(issue_coupons)が15分後に行う。ここでは
                      // 残高表示を最新化するだけ。
                      ref.read(pointsProvider.notifier).refresh();
                      final earnSec = ParkingSession.earnThreshold.inSeconds;
                      final earnLabel =
                          earnSec >= 60 ? '${earnSec ~/ 60}分' : '$earnSec秒';
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('認証完了！$earnLabel後にクーポンが届きます'),
                        ),
                      );
                      navigator.pop();
                      await navigator.push(
                        MaterialPageRoute(
                            builder: (_) => const SessionTimerPage()),
                      );
                    },
                    icon: const Icon(Icons.nfc_rounded, size: 20),
                    label: const Text('タッチで計測開始'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageBadge extends StatelessWidget {
  final int percent;
  final Color color;
  const _UsageBadge({required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '稼働 $percent%',
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool emphasis;
  const _Stat({
    required this.label,
    required this.value,
    required this.color,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: context.textSecondary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: emphasis ? FontWeight.w900 : FontWeight.w800,
            color: color,
            letterSpacing: -0.3,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: context.subtleBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeAvailabilitySection extends StatefulWidget {
  final ParkingLot parking;
  const _TimeAvailabilitySection({required this.parking});

  @override
  State<_TimeAvailabilitySection> createState() =>
      _TimeAvailabilitySectionState();
}

class _TimeAvailabilitySectionState extends State<_TimeAvailabilitySection> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = _initialSlotIndex(DateTime.now().hour);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slots = _buildSlots(widget.parking);
    final boundedIndex = _selectedIndex < 0
        ? 0
        : _selectedIndex >= slots.length
            ? slots.length - 1
            : _selectedIndex;
    final selected = slots[boundedIndex];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.subtleBorder),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(Icons.insights_rounded,
                    size: 16, color: AppColors.accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '時間帯別の空きやすさ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < slots.length; i++) ...[
                  Expanded(
                    child: _AvailabilityBar(
                      slot: slots[i],
                      selected: i == _selectedIndex,
                      onTap: () => setState(() => _selectedIndex = i),
                    ),
                  ),
                  if (i != slots.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected.color.withValues(alpha: 0.18)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(selected.icon, size: 18, color: selected.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${selected.label}は空き${selected.availableEstimate}台見込み。${selected.note}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _initialSlotIndex(int hour) {
    if (hour < 11) return 0;
    if (hour < 15) return 1;
    if (hour < 19) return 2;
    return 3;
  }

  List<_AvailabilitySlot> _buildSlots(ParkingLot parking) {
    final base = parking.capacity == 0
        ? 0.0
        : (parking.available / parking.capacity).clamp(0.0, 1.0).toDouble();
    final morning = (base + 0.16).clamp(0.08, 0.92).toDouble();
    final lunch = (base + 0.04).clamp(0.08, 0.9).toDouble();
    final evening = (base - 0.16).clamp(0.05, 0.82).toDouble();
    final night = (base + 0.08).clamp(0.08, 0.9).toDouble();

    return [
      _AvailabilitySlot(
        label: '朝',
        icon: Icons.wb_sunny_outlined,
        rate: morning,
        capacity: parking.capacity,
        color: AppColors.success,
        note: '通勤前の短時間利用に向いています。',
      ),
      _AvailabilitySlot(
        label: '昼',
        icon: Icons.restaurant_rounded,
        rate: lunch,
        capacity: parking.capacity,
        color: AppColors.accent,
        note: 'ランチ特典を取りに行く前に確認しやすい時間です。',
      ),
      _AvailabilitySlot(
        label: '夕方',
        icon: Icons.directions_bike_rounded,
        rate: evening,
        capacity: parking.capacity,
        color: evening < 0.25 ? AppColors.danger : AppColors.warning,
        note: '梅田周辺は混みやすいので早めの候補確認がおすすめです。',
      ),
      _AvailabilitySlot(
        label: '夜',
        icon: Icons.nights_stay_rounded,
        rate: night,
        capacity: parking.capacity,
        color: AppColors.accentAlt,
        note: '食事や買い物後の出庫前にも余裕を確認できます。',
      ),
    ];
  }
}

class _AvailabilitySlot {
  final String label;
  final IconData icon;
  final double rate;
  final int capacity;
  final Color color;
  final String note;

  const _AvailabilitySlot({
    required this.label,
    required this.icon,
    required this.rate,
    required this.capacity,
    required this.color,
    required this.note,
  });

  int get availableEstimate => (capacity * rate).round().clamp(0, capacity);
}

class _AvailabilityBar extends StatelessWidget {
  final _AvailabilitySlot slot;
  final bool selected;
  final VoidCallback onTap;

  const _AvailabilityBar({
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final barHeight = 36 + 34 * slot.rate;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.fromLTRB(6, 7, 6, 8),
          decoration: BoxDecoration(
            color: selected
                ? slot.color.withValues(alpha: 0.12)
                : context.subtleBorder.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? slot.color.withValues(alpha: 0.28)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 18,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: selected
                          ? slot.color
                          : slot.color.withValues(alpha: 0.34),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                slot.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? slot.color : context.textSecondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyCouponsSection extends StatelessWidget {
  final ParkingRecommendation recommendation;
  const _NearbyCouponsSection({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bonus = recommendation.bonusPointsPercent;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.08),
            AppColors.accentAlt.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.local_offer_rounded,
                    size: 14, color: AppColors.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '選ばれやすいクーポン',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (bonus > 0)
                Text(
                  '遠距離ボーナス +$bonus%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            children: recommendation.nearbyStores
                .map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: _NearbyStoreChip(store: s),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _NearbyStoreChip extends StatelessWidget {
  final Store store;
  const _NearbyStoreChip({required this.store});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: AppColors.accent.withValues(alpha: 0.25),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showAppBottomSheet<void>(
          context,
          builder: (_) => StorePreviewSheet(store: store),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.local_offer_rounded,
                      size: 14, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      store.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              if (store.recommendReason != null &&
                  store.recommendReason!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 12, color: context.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        store.recommendReason!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: context.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteButton extends ConsumerWidget {
  final String parkingId;
  const _FavoriteButton({required this.parkingId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoriteParkingsProvider);
    final isFav = favorites.contains(parkingId);
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            ref.read(favoriteParkingsProvider.notifier).toggle(parkingId),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            isFav ? Icons.star_rounded : Icons.star_border_rounded,
            size: 27,
            color: isFav ? AppColors.warning : context.textSecondary,
          ),
        ),
      ),
    );
  }
}
