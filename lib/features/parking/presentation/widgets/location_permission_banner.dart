import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/glass_decoration.dart';
import '../../providers/location_permission_providers.dart';

/// 位置情報の権限が無いときに地図上部に出すバナー。
///
/// granted のときは何も描画しない。
/// 「再度許可をリクエスト」または「設定アプリを開く」CTAを表示する。
class LocationPermissionBanner extends ConsumerWidget {
  final VoidCallback? onGranted;
  const LocationPermissionBanner({super.key, this.onGranted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(locationPermissionProvider);
    if (status == LocationGateStatus.granted ||
        status == LocationGateStatus.unknown) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final spec = _specFor(status);

    return Container(
      decoration: GlassDecoration.light(context, radius: 16),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(spec.icon, size: 18, color: AppColors.warning),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      spec.message,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _onPrimaryTap(context, ref, status),
                  icon: Icon(spec.primaryIcon, size: 16),
                  label: Text(spec.primaryLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    minimumSize: const Size.fromHeight(40),
                  ),
                ),
              ),
              if (spec.showSecondary) ...[
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _retry(ref),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('再確認'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onPrimaryTap(
    BuildContext context,
    WidgetRef ref,
    LocationGateStatus status,
  ) async {
    final notifier = ref.read(locationPermissionProvider.notifier);
    switch (status) {
      case LocationGateStatus.denied:
        final next = await notifier.request();
        if (next == LocationGateStatus.granted) onGranted?.call();
        break;
      case LocationGateStatus.deniedForever:
        await notifier.openAppSettings();
        break;
      case LocationGateStatus.serviceDisabled:
        await notifier.openLocationSettings();
        break;
      case LocationGateStatus.granted:
      case LocationGateStatus.unknown:
        break;
    }
  }

  Future<void> _retry(WidgetRef ref) async {
    final next =
        await ref.read(locationPermissionProvider.notifier).refresh();
    if (next == LocationGateStatus.granted) onGranted?.call();
  }

  _BannerSpec _specFor(LocationGateStatus status) {
    switch (status) {
      case LocationGateStatus.serviceDisabled:
        return const _BannerSpec(
          icon: Icons.location_disabled_rounded,
          title: '位置情報サービスがオフです',
          message: '端末の位置情報サービスをオンにすると、現在地から駐輪場を探せます。',
          primaryIcon: Icons.settings_rounded,
          primaryLabel: '位置情報の設定を開く',
          showSecondary: true,
        );
      case LocationGateStatus.deniedForever:
        return const _BannerSpec(
          icon: Icons.lock_outline_rounded,
          title: '位置情報の許可が必要です',
          message: '設定アプリでこのアプリの位置情報を「許可」に変更してください。',
          primaryIcon: Icons.open_in_new_rounded,
          primaryLabel: '設定アプリを開く',
          showSecondary: true,
        );
      case LocationGateStatus.denied:
      case LocationGateStatus.granted:
      case LocationGateStatus.unknown:
        return const _BannerSpec(
          icon: Icons.my_location_rounded,
          title: '現在地から駐輪場を探しませんか？',
          message: '位置情報を許可すると、距離順ソートやルート案内が使えます。',
          primaryIcon: Icons.check_rounded,
          primaryLabel: '位置情報を許可',
          showSecondary: false,
        );
    }
  }
}

class _BannerSpec {
  final IconData icon;
  final String title;
  final String message;
  final IconData primaryIcon;
  final String primaryLabel;
  final bool showSecondary;

  const _BannerSpec({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryIcon,
    required this.primaryLabel,
    required this.showSecondary,
  });
}
