import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/location_permission_providers.dart';

/// 位置情報が未許可のときに地図全体へ被せる全画面ゲート。
///
/// このアプリは現在地が前提のため、未許可時はまず全画面で許可を促す。
/// ただし「地図だけ見る」で [locationGateSkippedProvider] を立てて
/// ソフト表示（大阪駅周辺の目安）へ抜けられる。
///
/// granted / unknown / スキップ済みのときは何も描画しない。
class LocationGateOverlay extends ConsumerWidget {
  /// 許可が下りた直後のコールバック（現在地取得のトリガなど）。
  final VoidCallback? onGranted;

  const LocationGateOverlay({super.key, this.onGranted});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(locationPermissionProvider);
    final skipped = ref.watch(locationGateSkippedProvider);

    final hidden = skipped ||
        status == LocationGateStatus.granted ||
        status == LocationGateStatus.unknown;
    if (hidden) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final spec = _specFor(status);

    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(spec.icon, size: 32, color: AppColors.accent),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        spec.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        spec.message,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                        onPressed: () => _onPrimaryTap(ref, status),
                        icon: Icon(spec.primaryIcon, size: 18),
                        label: Text(spec.primaryLabel),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          minimumSize: const Size.fromHeight(48),
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => ref
                            .read(locationGateSkippedProvider.notifier)
                            .state = true,
                        child: Text(
                          '地図だけ見る',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: context.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onPrimaryTap(WidgetRef ref, LocationGateStatus status) async {
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

  _GateSpec _specFor(LocationGateStatus status) {
    switch (status) {
      case LocationGateStatus.serviceDisabled:
        return const _GateSpec(
          icon: Icons.location_disabled_rounded,
          title: '位置情報サービスをオンにしてください',
          message: 'BicycleGo は現在地をもとに近くの駐輪場を探すアプリです。'
              '端末の位置情報サービスをオンにすると利用できます。',
          primaryIcon: Icons.settings_rounded,
          primaryLabel: '位置情報の設定を開く',
        );
      case LocationGateStatus.deniedForever:
        return const _GateSpec(
          icon: Icons.lock_outline_rounded,
          title: '位置情報の許可が必要です',
          message: 'BicycleGo は現在地をもとに近くの駐輪場を探すアプリです。'
              '設定アプリでこのアプリの位置情報を「許可」に変更してください。',
          primaryIcon: Icons.open_in_new_rounded,
          primaryLabel: '設定アプリを開く',
        );
      case LocationGateStatus.denied:
      case LocationGateStatus.granted:
      case LocationGateStatus.unknown:
        return const _GateSpec(
          icon: Icons.my_location_rounded,
          title: '現在地の利用を許可してください',
          message: 'BicycleGo は現在地をもとに近くの駐輪場を探し、'
              '距離順の並び替えやルート案内を行います。',
          primaryIcon: Icons.check_rounded,
          primaryLabel: '位置情報を許可',
        );
    }
  }
}

class _GateSpec {
  final IconData icon;
  final String title;
  final String message;
  final IconData primaryIcon;
  final String primaryLabel;

  const _GateSpec({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryIcon,
    required this.primaryLabel,
  });
}
