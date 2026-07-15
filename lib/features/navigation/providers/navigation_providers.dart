import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/domain/parking_lot.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../parking/data/directions_service.dart';
import '../../parking/domain/directions_route.dart';
import '../../parking/providers/route_providers.dart';
import '../data/nav_voice_service.dart';
import '../domain/navigation_state.dart';
import '../domain/route_tracker.dart';

final navVoiceServiceProvider = Provider<NavVoiceService>(
  (_) => NavVoiceService(),
);

/// 音声案内のオン/オフ。端末に永続化する（ナビのたびに設定し直させない）。
class NavVoiceEnabled extends StateNotifier<bool> {
  NavVoiceEnabled(this._ref) : super(true) {
    _load();
  }

  final Ref _ref;

  static const _key = 'nav_voice_enabled_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? true;
    // 復元した設定を音量に反映（保存済みでミュートなら最初から無音で始める）。
    await _ref.read(navVoiceServiceProvider).setMuted(!state);
  }

  Future<void> toggle() async {
    state = !state;
    // 発話は止めず音量だけ切り替える。案内は裏で流れ続け、ボタンは出力の
    // オン/オフだけを担う（解除すれば以降の案内がそのまま聞こえる）。
    await _ref.read(navVoiceServiceProvider).setMuted(!state);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }
}

final navVoiceEnabledProvider =
    StateNotifierProvider<NavVoiceEnabled, bool>(NavVoiceEnabled.new);

/// 案内中のナビ。null で非案内。
final navigationControllerProvider =
    StateNotifierProvider<NavigationController, NavigationState?>(
  NavigationController.new,
);

class NavigationController extends StateNotifier<NavigationState?> {
  NavigationController(this._ref) : super(null);

  final Ref _ref;

  StreamSubscription<Position>? _positionSub;
  RouteTracker? _tracker;

  /// 読み上げ済みの案内。`"<区間index>:<しきい値>"` をキーにして重複読み上げを防ぐ。
  /// リルートで経路が入れ替わったらクリアする。
  final Set<String> _announced = {};

  /// 逸脱が連続した回数。単発の GPS 飛びでリルートを走らせないためのカウンタ。
  int _offRouteHits = 0;
  DateTime? _lastRerouteAt;
  bool _rerouting = false;

  /// 経路から何 m 離れたら逸脱とみなすか。
  static const double _offRouteThresholdMeters = 40;

  /// 逸脱がこの回数連続したらリルートする。
  static const int _offRouteHitsToReroute = 3;

  /// リルートの最小間隔。経路が取れない場所で API を叩き続けないようにする。
  static const Duration _rerouteCooldown = Duration(seconds: 12);

  /// 目的地にこの距離まで近づいたら到着とみなす。
  static const double _arrivalRadiusMeters = 30;

  /// 案内を開始する。[initialRoute] は地図でプレビュー済みの経路をそのまま使う。
  Future<void> start({
    required ParkingLot parking,
    required DirectionsRoute initialRoute,
  }) async {
    await _positionSub?.cancel();
    _announced.clear();
    _offRouteHits = 0;
    _lastRerouteAt = null;
    _rerouting = false;
    _tracker = RouteTracker(initialRoute);

    state = NavigationState(
      parking: parking,
      route: initialRoute,
      phase: NavPhase.locating,
    );

    _speak(
      '案内を開始します。${parking.name} まで'
      '${formatDistanceSpeech(initialRoute.distanceMeters.toDouble())}、'
      '約${(initialRoute.durationSeconds / 60).round()}分です。',
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: _locationSettings(parking.name),
    ).listen(
      _onPosition,
      onError: (Object e) {
        if (!mounted || state == null) return;
        state = state!.copyWith(error: '位置情報の取得に失敗しました（$e）');
      },
    );
  }

  /// ナビ中は画面を閉じても・アプリを離れても追従を続ける。
  /// Android は常設通知付きの前景サービス、iOS はバックグラウンド位置更新で実現する。
  LocationSettings _locationSettings(String parkingName) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        forceLocationManager: false,
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'ナビ案内中',
          notificationText: '$parkingName へ案内しています',
          notificationChannelName: 'ナビゲーション',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.otherNavigation,
        distanceFilter: 5,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
  }

  void _onPosition(Position position) {
    final current = state;
    final tracker = _tracker;
    if (!mounted || current == null || tracker == null) return;
    if (current.phase == NavPhase.arrived) return;

    final here = LatLng(position.latitude, position.longitude);
    final progress = tracker.locate(here);

    // GPS の heading は静止時に無意味な値を返すため、走行中のみ採用する。
    final heading = position.speed > 1.0 ? position.heading : null;

    state = current.copyWith(
      progress: progress,
      rawPosition: here,
      headingDegrees: heading,
      phase: current.phase == NavPhase.locating ? NavPhase.guiding : null,
    );

    if (_hasArrived(here, progress)) {
      _onArrived();
      return;
    }

    // 精度の悪いフィックス（屋内・ビル影）を逸脱と誤判定しない。
    // 誤差半径ぶんは経路からの距離を割り引いて見る。
    final effectiveDeviation =
        progress.distanceFromRouteMeters - (position.accuracy / 2);
    if (effectiveDeviation > _offRouteThresholdMeters) {
      _offRouteHits++;
      if (_offRouteHits >= _offRouteHitsToReroute) {
        unawaited(_reroute(here));
      }
    } else {
      _offRouteHits = 0;
      if (state!.phase == NavPhase.offRoute) {
        // 自力で経路に復帰した。
        state = state!.copyWith(phase: NavPhase.guiding, clearError: true);
      }
      _announceIfDue(state!, progress);
    }
  }

  bool _hasArrived(LatLng here, RouteProgress progress) {
    final toDestination =
        Geo.haversineMeters(here, state!.route.destination);
    return toDestination <= _arrivalRadiusMeters ||
        progress.remainingMeters <= _arrivalRadiusMeters / 2;
  }

  void _onArrived() {
    _positionSub?.cancel();
    _positionSub = null;
    state = state!.copyWith(phase: NavPhase.arrived, clearError: true);
    _speak('${state!.parking.name} に到着しました。お疲れさまでした。');
  }

  /// 次の曲がり角までの残り距離に応じて段階的に読み上げる。
  /// 同じ区間で同じ段階を二度読まないよう [_announced] で管理する。
  void _announceIfDue(NavigationState current, RouteProgress progress) {
    final upcomingIndex = progress.stepIndex + 1;
    final distance = progress.distanceToManeuverMeters;
    final instruction = current.upcomingInstruction;
    final currentStepLength = current.currentStep?.distanceMeters ?? 0;

    // 予告（250m 手前）。短い区間で「250m先」と「まもなく」を続けて読むと
    // うるさいので、十分長い区間でだけ流す。
    if (distance <= 250 &&
        currentStepLength > 300 &&
        _markAnnounced(upcomingIndex, 'far')) {
      _speak('${formatDistanceSpeech(distance)}先、$instruction');
      return;
    }
    if (distance <= 100 && _markAnnounced(upcomingIndex, 'near')) {
      _speak('まもなく、$instruction');
      return;
    }
    if (distance <= 30 && _markAnnounced(upcomingIndex, 'now')) {
      _speak(instruction);
    }
  }

  /// まだ読み上げていなければ記録して true。
  bool _markAnnounced(int stepIndex, String stage) =>
      _announced.add('$stepIndex:$stage');

  Future<void> _reroute(LatLng from) async {
    if (_rerouting) return;
    final since = _lastRerouteAt;
    if (since != null && DateTime.now().difference(since) < _rerouteCooldown) {
      return;
    }
    final current = state;
    if (current == null) return;

    _rerouting = true;
    _lastRerouteAt = DateTime.now();
    state = current.copyWith(phase: NavPhase.rerouting, clearError: true);
    _speak('経路を外れました。ルートを再検索します。');

    try {
      final route = await _ref.read(directionsServiceProvider).fetch(
            origin: from,
            parking: current.parking,
          );
      if (!mounted || state == null) return;

      _tracker = RouteTracker(route);
      _announced.clear();
      _offRouteHits = 0;
      state = state!.copyWith(
        route: route,
        progress: _tracker!.locate(from),
        phase: NavPhase.guiding,
        clearError: true,
      );
      // 地図プレビュー側の経路も新しいものに差し替える（ナビ終了後に古い経路が残らない）。
      _ref.read(activeRouteProvider.notifier).state = route;
      _speak('新しいルートで案内します。');
    } catch (e) {
      debugPrint('reroute failed: $e');
      if (!mounted || state == null) return;
      // 取得できなくても案内は畳まない。経路に戻れば自動で guiding に復帰する。
      state = state!.copyWith(
        phase: NavPhase.offRoute,
        error: e is DirectionsException
            ? e.message
            : 'ルートを再検索できませんでした',
      );
    } finally {
      _rerouting = false;
    }
  }

  /// 手動リルート（オフルートバナーの再試行ボタン）。
  Future<void> retryReroute() async {
    final here = state?.rawPosition;
    if (here == null) return;
    _lastRerouteAt = null;
    await _reroute(here);
  }

  void _speak(String text) {
    // ミュート中でも発話自体は流す。聞こえるかどうかは音量（setMuted）で決まる。
    // これで解除した瞬間から以降の案内がそのまま聞こえる。
    unawaited(_ref.read(navVoiceServiceProvider).speak(text));
  }

  /// 案内を終了して位置の追従（＝前景サービス）を止める。
  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _tracker = null;
    _announced.clear();
    await _ref.read(navVoiceServiceProvider).stop();
    if (mounted) state = null;
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    unawaited(_ref.read(navVoiceServiceProvider).stop());
    super.dispose();
  }
}
