import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../nfc/presentation/nfc_lock_sheet.dart';
import '../../points/providers/points_providers.dart';
import '../domain/parking_lot.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usage = parking.usageRatePercent / 100.0;
    final hh = parking.updatedAt.hour.toString().padLeft(2, '0');
    final mm = parking.updatedAt.minute.toString().padLeft(2, '0');
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentLocation = ref.watch(currentLocationProvider);
    final distanceMeters = currentLocation == null
        ? null
        : _distanceInMeters(currentLocation, parking.position);
    final walkingMinutes = distanceMeters == null
        ? null
        : (distanceMeters / 80.0).round(); // 80m/分 = 4.8km/h
    final usageColor = _usageColor(usage, colorScheme);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  parking.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _InfoChip(
                icon: Icons.equalizer,
                label: '${parking.usageRatePercent}%',
                color: usageColor,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceVariant.withOpacity(0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _InfoChip(
                      icon: Icons.local_parking,
                      label: '空き ${parking.available}',
                      color: usageColor,
                    ),
                    const SizedBox(width: 8),
                    _InfoChip(
                      icon: Icons.layers_outlined,
                      label: '収容 ${parking.capacity}',
                      color: colorScheme.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: usage,
                    minHeight: 8,
                    color: usageColor,
                    backgroundColor: colorScheme.surface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.payments_outlined,
                label: '${parking.priceYenPerDay}円 / 日',
                color: colorScheme.secondary,
              ),
              _InfoChip(
                icon: Icons.update,
                label: '更新 $hh:$mm',
                color: colorScheme.tertiary,
              ),
              if (distanceMeters == null)
                _InfoChip(
                  icon: Icons.location_searching,
                  label: '距離 取得中',
                  color: colorScheme.outline,
                )
              else ...[
                _InfoChip(
                  icon: Icons.place_outlined,
                  label:
                      '約${(distanceMeters / 1000).toStringAsFixed(1)}km',
                  color: colorScheme.primary,
                ),
                _InfoChip(
                  icon: Icons.directions_walk,
                  label: '徒歩 約$walkingMinutes分',
                  color: colorScheme.primary,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    messenger.showSnackBar(
                      SnackBar(content: Text('${parking.name}に駐輪しました')),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('ここに停める'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () async {
                    final isSuccess = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (_) => NfcLockSheet(parkingName: parking.name),
                    );
                    if (isSuccess == true) {
                      ref.read(pointsProvider.notifier).state +=
                          _nfcLockRewardPoints;
                      messenger.showSnackBar(
                        const SnackBar(content: Text('ポイントを獲得しました +10pt')),
                      );
                    }
                  },
                  child: const Text('NFCでロック'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('閉じる'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Color _usageColor(double usage, ColorScheme scheme) {
  if (usage >= 0.8) {
    return scheme.error;
  }
  if (usage >= 0.5) {
    return scheme.tertiary;
  }
  return scheme.primary;
}
