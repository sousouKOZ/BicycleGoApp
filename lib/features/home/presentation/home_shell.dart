import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/api_providers.dart';
import '../../coupons/domain/coupon.dart';
import '../../coupons/presentation/coupon_list_page.dart';
import '../../mypage/presentation/my_page.dart';
import '../../parking/domain/parking_session.dart';
import '../../parking/presentation/parking_map_page.dart';
import '../../parking/providers/session_providers.dart';
import '../../points/providers/points_providers.dart';
import '../../user/providers/user_providers.dart';
import '../../sessions/presentation/coupon_earned_page.dart';
import '../../sessions/presentation/session_mini_bar.dart';
import '../../sessions/providers/session_history_providers.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  int index = 0;
  RealtimeChannel? _sessionChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // サーバ側 issue_coupons (pg_cron) が15分達成を自律検知するため、
    // クライアントポーリングは不要。Realtime で achieved 遷移を待つ。
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreFromServer();
      _subscribeToSessionUpdates();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // バックグラウンドから戻ったとき、Realtime WebSocket が OS に切られて
    // achieved 遷移を取りこぼしている可能性があるためサーバ状態を再取得する。
    // FCM 通知タップで起動した場合もこの経路で祝福画面が出る。
    if (state == AppLifecycleState.resumed) {
      _restoreFromServer();
    }
  }

  Future<void> _restoreFromServer() async {
    if (!mounted) return;
    try {
      if (ref.read(activeSessionProvider) != null) {
        await _handleAchievedSession();
        return;
      }

      final api = ref.read(apiClientProvider);
      final userId = ref.read(currentUserIdProvider);
      final session = await api.getActiveSession(userId);
      if (session != null && mounted) {
        ref.read(activeSessionProvider.notifier).state = session;

        // 駐輪場情報も復元（履歴記録・achieved 画面表示のため）
        try {
          final parkingInfo = await api.getParkingForDevice(session.deviceId);
          if (parkingInfo != null && mounted) {
            ref.read(activeParkingInfoProvider.notifier).state = parkingInfo;
          }
        } catch (_) {
          // 取れなくてもセッション復元自体は継続
        }
      }

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
        ref.read(activeSessionProvider.notifier).state =
            session.copyWith(status: ParkingSessionStatus.parked);
        return;
      }

      if (matched.status == CouponStatus.used) {
        ref.read(activeSessionProvider.notifier).state =
            session.copyWith(status: ParkingSessionStatus.parked);
        return;
      }

      if (!mounted) return;
      ref.read(latestEarnedCouponProvider.notifier).state = matched;
      ref.read(pointsProvider.notifier).refresh();
      ref.invalidate(sessionHistoryProvider);

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
    WidgetsBinding.instance.removeObserver(this);
    if (_sessionChannel != null) {
      Supabase.instance.client.removeChannel(_sessionChannel!);
      _sessionChannel = null;
    }
    super.dispose();
  }

  /// parking_sessions の自分の行が UPDATE されたら祝福画面遷移を判定する。
  /// サーバ側 issue_coupons が status を 'achieved' に書き換えた瞬間に発火する。
  void _subscribeToSessionUpdates() {
    if (!mounted || _sessionChannel != null) return;
    final userId = ref.read(currentUserIdProvider);
    final client = Supabase.instance.client;
    _sessionChannel = client
        .channel('home_session_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'parking_sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) => _onSessionUpdated(payload.newRecord),
        )
        .subscribe();
  }

  Future<void> _onSessionUpdated(Map<String, dynamic> row) async {
    if (!mounted) return;
    final status = row['status'] as String?;
    final current = ref.read(activeSessionProvider);
    final isOwnSession = current != null && current.id == row['id'];

    // 自転車取り出しや猶予超過でセッションが終了した場合、
    // アクティブセッション表示（ミニバー等）を即時クリアする。
    if (status == 'expired' || status == 'completed') {
      if (isOwnSession) {
        ref.read(activeSessionProvider.notifier).state = null;
        ref.read(activeParkingInfoProvider.notifier).state = null;
        ref.invalidate(sessionHistoryProvider);
      }
      return;
    }

    if (status != 'achieved') return;

    if (isOwnSession) {
      ref.read(activeSessionProvider.notifier).state = current.copyWith(
        status: ParkingSessionStatus.achieved,
        issuedCouponId: row['issued_coupon_id'] as String?,
      );
    }
    await _handleAchievedSession();
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
