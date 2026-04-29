import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../stores/domain/store.dart';
import '../../stores/presentation/store_preview_sheet.dart';
import '../../stores/providers/store_providers.dart';
import '../data/directions_service.dart';
import '../providers/favorite_providers.dart';
import '../providers/recommendation_providers.dart';
import '../providers/route_providers.dart';
import '../../nfc/presentation/nfc_lock_sheet.dart';
import '../../points/providers/points_providers.dart';
import '../../sessions/presentation/session_timer_page.dart';
import '../data/parking_mock_data.dart';
import '../domain/parking_lot.dart';
import '../domain/parking_session.dart';
import '../providers/parking_providers.dart';

class ParkingDetailSheet extends ConsumerWidget {
  final ParkingLot parking;
  const ParkingDetailSheet({super.key, required this.parking});

  static const int _nfcLockRewardPoints = 10;

  double _distanceInMeters(LatLng start, LatLng end) {
    const earthRadius = 6371000.0;
    final dLat = _toRadians(end.latitude - start.latitude);
    final dLon = _toRadians(end.longitude - start.longitude);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRadians(start.latitude)) *
            math.cos(_toRadians(end.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _toRadians(double degree) => degree * (math.pi / 180.0);

  /// 上部の _RouteBanner と表記を揃えるため、1km 未満は m 表記、それ以上は km 表記。
  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '約${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '約${meters.round()}m';
  }

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
    final hh = parking.updatedAt.hour.toString().padLeft(2, '0');
    final mm = parking.updatedAt.minute.toString().padLeft(2, '0');
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final currentLocation = ref.watch(currentLocationProvider);
    // ルートを取得済みなら同じ値（自転車経路の実距離・実所要時間）を使い、
    // 上部の _RouteBanner と完全に一致させる。
    // 未取得時は直線距離 + 自転車速度（250m/分 ≒ 15km/h）で見積もり。
    final activeRoute = ref.watch(activeRouteProvider);
    final useRoute = activeRoute != null &&
        activeRoute.parkingLotId == parking.id;
    final distanceMeters = useRoute
        ? activeRoute.distanceMeters.toDouble()
        : currentLocation == null
            ? null
            : _distanceInMeters(currentLocation, parking.position);
    final cyclingMinutes = useRoute
        ? (activeRoute.durationSeconds / 60).round()
        : distanceMeters == null
            ? null
            : (distanceMeters / 250.0).round().clamp(1, 999);
    final usageColor = _usageColor(usage);
    final stores = ref.watch(storesProvider).asData?.value ?? const <Store>[];
    final recommendation = computeRecommendation(
      parking: parking,
      stores: stores,
      userLocation: currentLocation,
    );

    return Padding(
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
                    _Stat(
                      label: '空き',
                      value: '${parking.available}',
                      emphasis: true,
                      color: usageColor,
                    ),
                    const SizedBox(width: 18),
                    Container(
                      width: 1,
                      height: 36,
                      color: context.subtleBorder,
                    ),
                    const SizedBox(width: 18),
                    _Stat(
                      label: '収容',
                      value: '${parking.capacity}',
                      color: context.textPrimary,
                    ),
                    const SizedBox(width: 18),
                    Container(
                      width: 1,
                      height: 36,
                      color: context.subtleBorder,
                    ),
                    const SizedBox(width: 18),
                    _Stat(
                      label: '料金/日',
                      value: '¥${parking.priceYenPerDay}',
                      color: context.textPrimary,
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
                    backgroundColor:
                        usageColor.withValues(alpha: 0.15),
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
                label: '更新 $hh:$mm',
              ),
              if (distanceMeters == null)
                _MetaChip(
                  icon: Icons.location_searching,
                  label: '距離 取得中',
                )
              else ...[
                _MetaChip(
                  icon: Icons.place_outlined,
                  label: _formatDistance(distanceMeters),
                ),
                _MetaChip(
                  icon: Icons.directions_bike_rounded,
                  label: '自転車 約$cyclingMinutes分',
                ),
              ],
            ],
          ),
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
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
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
                        await showModalBottomSheet<ParkingSession?>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => NfcLockSheet(
                        parkingId: parking.id,
                        parkingName: parking.name,
                        deviceId: device.id,
                      ),
                    );
                    if (session == null) {
                      return;
                    }
                    ref
                        .read(pointsProvider.notifier)
                        .add(_nfcLockRewardPoints);
                    final earnSec =
                        ParkingSession.earnThreshold.inSeconds;
                    final earnLabel = earnSec >= 60
                        ? '${earnSec ~/ 60}分'
                        : '${earnSec}秒';
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

Color _usageColor(double usage) {
  if (usage >= 0.85) return AppColors.danger;
  if (usage >= 0.6) return AppColors.warning;
  return AppColors.success;
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
              Text(
                '近くで使えるクーポン',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              if (bonus > 0)
                Text(
                  '遠距離ボーナス +$bonus%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: recommendation.nearbyStores
                .map((s) => _NearbyStoreChip(store: s))
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
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => StorePreviewSheet(store: store),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_offer_rounded,
                  size: 12, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                store.name,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            isFav ? Icons.star_rounded : Icons.star_border_rounded,
            size: 26,
            color: isFav ? AppColors.warning : context.textSecondary,
          ),
        ),
      ),
    );
  }
}
