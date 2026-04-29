import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/config/api_config.dart';
import '../../coupons/domain/coupon.dart';
import '../../coupons/presentation/coupon_list_page.dart';
import '../../coupons/providers/coupon_providers.dart';
import '../../mypage/presentation/my_page.dart';
import '../../parking/domain/parking_session.dart';
import '../../parking/presentation/parking_map_page.dart';
import '../../parking/providers/session_providers.dart';
import '../../points/providers/points_providers.dart';
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
    // Supabase モード: アプリ起動時にサーバ自律発行されたクーポンを検知して
    // 祝福画面を表示する。アプリを kill した状態で 15分達成 → 通知タップで開いた
    // ケースをカバー。
    if (useSupabase) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _checkUnseenEarnedCoupon(),
      );
    }
  }

  static const _lastSeenCouponKey = 'last_seen_earned_coupon_id_v1';

  Future<void> _checkUnseenEarnedCoupon() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getString(_lastSeenCouponKey);

      // 最新の所有クーポンを取得
      final coupons =
          await ref.read(userCouponsProvider.future);
      Coupon? newest;
      for (final c in coupons) {
        if (c.status != CouponStatus.owned) continue;
        if (c.distanceTier == CouponDistanceTier.exchange) continue; // 交換クーポンは除外
        if (newest == null || c.issuedAt.isAfter(newest.issuedAt)) {
          newest = c;
        }
      }
      if (newest == null) return;
      if (lastSeen == newest.id) return; // 既に表示済み

      // 5分以上前のクーポンは祝福しない（古い未消化を毎回出さない）
      if (DateTime.now().difference(newest.issuedAt) >
          const Duration(minutes: 5)) {
        await prefs.setString(_lastSeenCouponKey, newest.id);
        return;
      }

      await prefs.setString(_lastSeenCouponKey, newest.id);
      // ポイント残高もリフレッシュ
      ref.read(pointsProvider.notifier).refresh();

      if (!mounted) return;
      ref.read(latestEarnedCouponProvider.notifier).state = newest;
      final navigator = Navigator.of(context, rootNavigator: true);
      await navigator.push(
        MaterialPageRoute(builder: (_) => const CouponEarnedPage()),
      );
    } catch (_) {
      // 起動時の失敗はサイレント（次回起動時に再試行）
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
        await ref.read(sessionHistoryProvider.notifier).add(
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
