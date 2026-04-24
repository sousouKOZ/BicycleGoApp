import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api/api_providers.dart';
import '../../coupons/presentation/coupon_list_page.dart';
import '../../mypage/presentation/my_page.dart';
import '../../parking/domain/parking_session.dart';
import '../../parking/presentation/parking_map_page.dart';
import '../../parking/providers/session_providers.dart';
import '../../sessions/presentation/coupon_earned_page.dart';
import '../../sessions/presentation/session_mini_bar.dart';

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
