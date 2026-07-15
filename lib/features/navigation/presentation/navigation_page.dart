import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/domain/parking_lot.dart';
import '../../../core/theme/app_colors.dart';
import '../../parking/domain/directions_route.dart';
import '../../parking/presentation/start_parking_flow.dart';
import '../../parking/presentation/widgets/map_marker_icons.dart';
import '../../parking/providers/route_providers.dart';
import '../../parking/providers/session_providers.dart';
import '../../sessions/presentation/session_timer_page.dart';
import '../domain/navigation_state.dart';
import '../domain/route_tracker.dart';
import '../providers/navigation_providers.dart';
import 'widgets/maneuver_card.dart';
import 'widgets/nav_arrival_panel.dart';
import 'widgets/nav_bottom_bar.dart';
import 'widgets/off_route_banner.dart';

/// ターンバイターン案内のフルスクリーン画面。
class NavigationPage extends ConsumerStatefulWidget {
  final ParkingLot parking;

  /// 地図でプレビュー済みの経路。案内開始時に取り直さず、そのまま使う。
  final DirectionsRoute initialRoute;

  const NavigationPage({
    super.key,
    required this.parking,
    required this.initialRoute,
  });

  @override
  ConsumerState<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends ConsumerState<NavigationPage> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _puckIcon;

  /// カメラが現在地を追い続けるか。ユーザーが地図を触ったら解除する。
  bool _following = true;

  /// 自前で動かしたカメラ移動の時刻。onCameraMoveStarted は自前の移動でも
  /// 発火するため、直前に自分で動かしたかどうかで指操作と切り分ける。
  DateTime? _lastProgrammaticMoveAt;

  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadPuckIcon();
    // build 前に provider を書き換えられないので、最初のフレーム後に開始する。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(navigationControllerProvider.notifier).start(
            parking: widget.parking,
            initialRoute: widget.initialRoute,
          );
    });
  }

  Future<void> _loadPuckIcon() async {
    final icon = await createCircleIconMarker(
      icon: Icons.navigation_rounded,
      backgroundColor: AppColors.navigation,
    );
    if (!mounted) return;
    setState(() => _puckIcon = icon);
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _followCameraTo(NavigationState nav) {
    final controller = _mapController;
    final progress = nav.progress;
    if (controller == null || progress == null || !_following) return;

    _lastProgrammaticMoveAt = DateTime.now();
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: progress.snapped,
          zoom: 17.5,
          tilt: 55,
          // 走行中は GPS の進行方向、停止中は経路の接線方向を向く。
          bearing: nav.headingDegrees ?? progress.courseDegrees,
        ),
      ),
    );
  }

  void _onCameraMoveStarted() {
    final last = _lastProgrammaticMoveAt;
    final isOwnMove = last != null &&
        DateTime.now().difference(last) < const Duration(milliseconds: 600);
    if (isOwnMove || !_following) return;
    setState(() => _following = false);
  }

  void _recenter() {
    setState(() => _following = true);
    final nav = ref.read(navigationControllerProvider);
    if (nav != null) _followCameraTo(nav);
  }

  Future<void> _exit({bool confirm = true}) async {
    if (confirm) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('ナビを終了しますか？'),
          content: const Text('案内を終了して地図に戻ります。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('続ける'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('終了する'),
            ),
          ],
        ),
      );
      if (leave != true) return;
    }
    await ref.read(navigationControllerProvider.notifier).stop();
    if (mounted) Navigator.of(context).pop();
  }

  /// 到着パネルから駐輪認証へ。ナビの出口をそのまま駐輪の入口にする。
  Future<void> _startParking() async {
    setState(() => _authInProgress = true);
    final navigator = Navigator.of(context);
    final session = await runParkingAuth(context, ref, widget.parking);
    if (!mounted) return;
    setState(() => _authInProgress = false);
    if (session == null) return;

    await ref.read(navigationControllerProvider.notifier).stop();
    // 案内が終わったので地図側のプレビュー経路も畳む。
    ref.read(activeRouteProvider.notifier).state = null;
    if (!mounted) return;

    navigator.pop();
    await navigator.push(
      MaterialPageRoute(builder: (_) => const SessionTimerPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nav = ref.watch(navigationControllerProvider);
    final voiceEnabled = ref.watch(navVoiceEnabledProvider);
    final hasActiveSession = ref.watch(activeSessionProvider) != null;

    ref.listen<NavigationState?>(navigationControllerProvider, (_, next) {
      if (next != null) _followCameraTo(next);
    });

    // stop() 後の 1 フレームなど、state が null になり得る。
    // 直前まで見えていた経路を保って画面のちらつきを防ぐ。
    final route = nav?.route ?? widget.initialRoute;
    final arrived = nav?.phase == NavPhase.arrived;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 到着後は案内するものが無いので確認なしで閉じる。
        _exit(confirm: !arrived);
      },
      child: Scaffold(
        body: Stack(
          children: [
            _NavMap(
              route: route,
              progress: nav?.progress,
              puckIcon: _puckIcon,
              onMapCreated: (controller) {
                _mapController = controller;
                final current = ref.read(navigationControllerProvider);
                if (current != null) _followCameraTo(current);
              },
              onCameraMoveStarted: _onCameraMoveStarted,
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  children: [
                    if (nav != null && !arrived) ...[
                      if (nav.isOffRoute)
                        OffRouteBanner(
                          phase: nav.phase,
                          error: nav.error,
                          onRetry: () => ref
                              .read(navigationControllerProvider.notifier)
                              .retryReroute(),
                        )
                      else
                        ManeuverCard(
                          maneuver: nav.upcomingManeuver,
                          instruction: nav.upcomingInstruction,
                          distanceMeters: nav.distanceToManeuverMeters,
                          followingStep: nav.followingStep,
                        ),
                    ],
                    const Spacer(),
                    if (!_following)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FloatingActionButton.small(
                            heroTag: 'nav-recenter',
                            onPressed: _recenter,
                            child: const Icon(Icons.navigation_rounded),
                          ),
                        ),
                      ),
                    if (nav != null && arrived)
                      NavArrivalPanel(
                        parking: nav.parking,
                        hasActiveSession: hasActiveSession,
                        authInProgress: _authInProgress,
                        onStartParking: _startParking,
                        onClose: () => _exit(confirm: false),
                      )
                    else
                      NavBottomBar(
                        eta: nav?.eta ??
                            DateTime.now().add(
                              Duration(seconds: route.durationSeconds),
                            ),
                        remainingSeconds:
                            nav?.remainingSeconds ?? route.durationSeconds,
                        remainingMeters: nav?.remainingMeters ??
                            route.distanceMeters.toDouble(),
                        voiceEnabled: voiceEnabled,
                        onToggleVoice: () => ref
                            .read(navVoiceEnabledProvider.notifier)
                            .toggle(),
                        onExit: _exit,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 経路・現在地・目的地を描く地図。オーバーレイの setState で
/// 作り直されないようウィジェットを分けている。
class _NavMap extends StatelessWidget {
  final DirectionsRoute route;
  final RouteProgress? progress;
  final BitmapDescriptor? puckIcon;
  final void Function(GoogleMapController) onMapCreated;
  final VoidCallback onCameraMoveStarted;

  const _NavMap({
    required this.route,
    required this.progress,
    required this.puckIcon,
    required this.onMapCreated,
    required this.onCameraMoveStarted,
  });

  @override
  Widget build(BuildContext context) {
    final path = route.polyline;
    final polylines = <Polyline>{};
    final current = progress;

    // 走行済みは淡く、これから走る区間は濃く。どこまで来たかが一目で分かる。
    if (current != null && path.length >= 2) {
      final index = current.segmentIndex.clamp(0, path.length - 1);
      final snapped = current.snapped;
      polylines.add(Polyline(
        polylineId: const PolylineId('nav-traveled'),
        points: [...path.sublist(0, index + 1), snapped],
        color: AppColors.onSurfaceSecondary.withValues(alpha: 0.45),
        width: 8,
        jointType: JointType.round,
      ));
      polylines.add(Polyline(
        polylineId: const PolylineId('nav-remaining'),
        points: [snapped, ...path.sublist(index + 1)],
        color: AppColors.navigation,
        width: 8,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 1,
      ));
    } else {
      polylines.add(Polyline(
        polylineId: const PolylineId('nav-remaining'),
        points: path,
        color: AppColors.navigation,
        width: 8,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
    }

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('nav-destination'),
        position: route.destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: route.parkingName),
      ),
    };
    if (current != null) {
      markers.add(Marker(
        markerId: const MarkerId('nav-puck'),
        position: current.snapped,
        icon: puckIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        anchor: const Offset(0.5, 0.5),
        flat: true,
        // カメラごと進行方向へ回すので、アイコンは常に画面上向き。
        rotation: 0,
        zIndexInt: 2,
      ));
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: route.origin,
        zoom: 17.5,
        tilt: 55,
      ),
      polylines: polylines,
      markers: markers,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      onMapCreated: onMapCreated,
      onCameraMoveStarted: onCameraMoveStarted,
    );
  }
}
