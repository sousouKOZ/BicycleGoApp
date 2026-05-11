import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/config/api_config.dart';
import '../../coupons/domain/coupon.dart';
import '../../coupons/presentation/coupon_list_page.dart';
import '../../mypage/presentation/my_page.dart';
import '../../parking/domain/parking_session.dart';
import '../../parking/presentation/parking_map_page.dart';
import '../../parking/providers/session_providers.dart';
import '../../points/providers/points_providers.dart';
import '../../user/providers/user_providers.dart';
import '../../sessions/domain/session_record.dart';
import '../../sessions/presentation/coupon_earned_page.dart';
import '../../sessions/presentation/session_mini_bar.dart';
import '../../sessions/providers/session_history_providers.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int index = 0;
  Timer? _sessionTicker;
  bool _issuing = false;

  @override
  void initState() {
    super.initState();
    _sessionTicker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkSession(),
    );
    // Supabase モード: アプリ起動時にサーバから状態を復元する。
    //   1. 測定中／達成済／駐輪継続中のセッションがあれば activeSessionProvider に復元
    //      → ミニバーが即時表示される（kill 後の再起動で進捗バーが消えるのを防ぐ）
    //   2. 未表示の達成クーポンがあれば祝福画面に自動遷移
    //      （kill 状態で15分達成 → 通知タップ→起動 のケース）
    if (useSupabase) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _restoreFromServer(),
      );
    }
  }

  Future<void> _restoreFromServer() async {
    if (!mounted) return;
    try {
      // 既にメモリ上にセッションがある（hot reload 等）なら何もしない。
      if (ref.read(activeSessionProvider) != null) {
        await _handleAchievedSession();
        return;
      }

      final api = ref.read(apiClientProvider);
      final userId = ref.read(currentUserIdProvider);
      final session = await api.getActiveSession(userId);
      if (session != null && mounted) {
        ref.read(activeSessionProvider.notifier).state = session;

        // 駐輪場情報も復元（CheckoutSheet・履歴記録のため）
        try {
          final parkingInfo = await api.getParkingForDevice(session.deviceId);
          if (parkingInfo != null && mounted) {
            ref.read(activeParkingInfoProvider.notifier).state = parkingInfo;
          }
        } catch (_) {
          // 取れなくてもセッション復元自体は継続
        }
      }

      // achieved 状態なら即時クーポン獲得画面に遷移
      await _handleAchievedSession();
    } catch (_) {
      // 起動時の失敗はサイレント（ネット不調・初回起動等）
    }
  }

  /// セッションが `achieved` のとき、対応するクーポンを取得して
  /// CouponEarnedPage に遷移する。これがミニバーの「クーポン発行中」状態を解消する唯一の出口。
  /// ユーザーが画面で「使う」or「あとで使う」を選ぶと session が次状態に遷移してバーが消える。
  Future<void> _handleAchievedSession() async {
    if (!mounted) return;
    final session = ref.read(activeSessionProvider);
    if (session == null ||
        session.status != ParkingSessionStatus.achieved ||
        session.issuedCouponId == null) {
      return;
    }

    try {
      final api = ref.read(apiClientProvider);
      final userId = ref.read(currentUserIdProvider);
      final coupons = await api.getUserCoupons(userId);

      Coupon? matched;
      for (final c in coupons) {
        if (c.id == session.issuedCouponId) {
          matched = c;
          break;
        }
      }
      if (matched == null) {
        // クーポンレコードが取れない異常系：セッションは parked に倒してバー解消
        ref.read(activeSessionProvider.notifier).state =
            session.copyWith(status: ParkingSessionStatus.parked);
        return;
      }

      // 既に消込済みのクーポンならフローを進めるだけ（祝福画面は出さない）
      if (matched.status == CouponStatus.used) {
        ref.read(activeSessionProvider.notifier).state =
            session.copyWith(status: ParkingSessionStatus.parked);
        return;
      }

      // 駐輪履歴を追加（_checkSession のローカル発行経路を通らない場合の取りこぼし対策）。
      // 同じ session.id で既に登録済みなら addIfAbsent が no-op。
      final parkingInfo = ref.read(activeParkingInfoProvider);
      if (parkingInfo != null && session.authenticatedAt != null) {
        await ref.read(sessionHistoryProvider.notifier).addIfAbsent(
              SessionRecord(
                id: session.id,
                parkingId: parkingInfo.parkingId,
                parkingName: parkingInfo.parkingName,
                startedAt: session.authenticatedAt!,
                completedAt: matched.issuedAt,
                earnedPoints: 10,
                issuedCouponId: matched.id,
                couponBenefit: matched.benefit,
              ),
            );
      }

      if (!mounted) return;
      ref.read(latestEarnedCouponProvider.notifier).state = matched;
      ref.read(pointsProvider.notifier).refresh();

      final navigator = Navigator.of(context, rootNavigator: true);
      await navigator.push(
        MaterialPageRoute(builder: (_) => const CouponEarnedPage()),
      );
    } catch (_) {
      // ネット不調等：次回起動時に再試行される
    }
  }

  @override
  void dispose() {
    _sessionTicker?.cancel();
    super.dispose();
  }

  Future<void> _checkSession() async {
    if (_issuing || !mounted) return;
    final session = ref.read(activeSessionProvider);
    if (session == null ||
        session.authenticatedAt == null ||
        session.status != ParkingSessionStatus.measuring) {
      return;
    }
    final elapsed = DateTime.now().difference(session.authenticatedAt!);
    if (elapsed < ParkingSession.earnThreshold) return;

    _issuing = true;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final coupon = await ref.read(apiClientProvider).evaluateEarn(
            sessionId: session.id,
            userLat: pos.latitude,
            userLng: pos.longitude,
          );
      if (coupon == null || !mounted) return;
      ref.read(activeSessionProvider.notifier).state =
          session.copyWith(status: ParkingSessionStatus.achieved);
      ref.read(latestEarnedCouponProvider.notifier).state = coupon;
      final parkingInfo = ref.read(activeParkingInfoProvider);
      if (parkingInfo != null) {
        await ref.read(sessionHistoryProvider.notifier).addIfAbsent(
              SessionRecord(
                id: session.id,
                parkingId: parkingInfo.parkingId,
                parkingName: parkingInfo.parkingName,
                startedAt: session.authenticatedAt!,
                completedAt: DateTime.now(),
                earnedPoints: 10,
                issuedCouponId: coupon.id,
                couponBenefit: coupon.benefit,
              ),
            );
      }
      if (!mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      navigator.popUntil((r) => r.isFirst);
      await navigator.push(
        MaterialPageRoute(builder: (_) => const CouponEarnedPage()),
      );
    } catch (_) {
      // ignore; retry on next tick
    } finally {
      _issuing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ParkingMapPage(),
      const CouponListPage(),
      const MyPage(),
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SessionMiniBar(),
          NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => setState(() => index = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.map), label: '地図'),
              NavigationDestination(
                  icon: Icon(Icons.confirmation_number), label: 'クーポン'),
              NavigationDestination(icon: Icon(Icons.person), label: 'マイページ'),
            ],
          ),
        ],
      ),
    );
  }
}
