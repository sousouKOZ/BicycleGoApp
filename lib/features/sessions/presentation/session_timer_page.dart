import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api/api_providers.dart';
import '../../parking/domain/parking_session.dart';
import '../../parking/providers/session_providers.dart';
import '../../stores/domain/store.dart';
import '../../stores/providers/store_providers.dart';
import 'coupon_earned_page.dart';

class SessionTimerPage extends ConsumerStatefulWidget {
  const SessionTimerPage({super.key});

  @override
  ConsumerState<SessionTimerPage> createState() => _SessionTimerPageState();
}

class _SessionTimerPageState extends ConsumerState<SessionTimerPage> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  bool _issuing = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final session = ref.read(activeSessionProvider);
    if (session == null || session.authenticatedAt == null) {
      return;
    }
    if (!mounted) return;
    final elapsed = DateTime.now().difference(session.authenticatedAt!);
    setState(() => _elapsed = elapsed);
    if (elapsed >= ParkingSession.earnThreshold &&
        session.status == ParkingSessionStatus.measuring &&
        !_issuing) {
      _issueCoupon(session);
    }
  }

  Future<void> _issueCoupon(ParkingSession session) async {
    setState(() => _issuing = true);
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final api = ref.read(apiClientProvider);
      final coupon = await api.evaluateEarn(
        sessionId: session.id,
        userLat: pos.latitude,
        userLng: pos.longitude,
      );
      if (coupon == null || !mounted) return;
      ref.read(activeSessionProvider.notifier).state =
          session.copyWith(status: ParkingSessionStatus.achieved);
      ref.read(latestEarnedCouponProvider.notifier).state = coupon;
      _ticker?.cancel();
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CouponEarnedPage()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _issuing = false);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    final theme = Theme.of(context);
    if (session == null || session.authenticatedAt == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('計測中')),
        body: const Center(child: Text('有効なセッションがありません')),
      );
    }

    final total = ParkingSession.earnThreshold.inSeconds;
    final secondsPassed = _elapsed.inSeconds.clamp(0, total);
    final secondsLeft = (total - secondsPassed).clamp(0, total);
    final progress = secondsPassed / total;
    final mm = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final ss = (secondsLeft % 60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('駐輪計測中'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CountdownCard(
                progress: progress,
                mm: mm,
                ss: ss,
                isAchieving: _issuing,
              ),
              const SizedBox(height: 20),
              Text(
                '待機中に行ってみる？',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '15分達成でクーポンを自動発行します',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 10),
              const Expanded(child: _StoreCarousel()),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _issuing ? null : _cancelSession,
                child: const Text('計測を中止する'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelSession() async {
    final session = ref.read(activeSessionProvider);
    if (session == null) {
      Navigator.of(context).pop();
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('計測を中止しますか？'),
        content: const Text('15分経過前に中止するとクーポンは発行されません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('中止する'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(apiClientProvider).endSession(session.id);
    ref.read(activeSessionProvider.notifier).state = null;
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

class _CountdownCard extends StatelessWidget {
  final double progress;
  final String mm;
  final String ss;
  final bool isAchieving;
  const _CountdownCard({
    required this.progress,
    required this.mm,
    required this.ss,
    required this.isAchieving,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            width: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 160,
                  width: 160,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 10,
                    backgroundColor: scheme.surface,
                    color: scheme.primary,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAchieving ? '発行中…' : '$mm:$ss',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isAchieving ? 'クーポンを選定中' : 'クーポン獲得まで',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bike, size: 18, color: scheme.onPrimaryContainer),
              const SizedBox(width: 6),
              Text(
                '停めてスキャン完了 → あとは街を楽しむだけ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoreCarousel extends ConsumerWidget {
  const _StoreCarousel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStores = ref.watch(storesProvider);
    return asyncStores.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('店舗情報取得失敗: $e')),
      data: (stores) {
        if (stores.isEmpty) {
          return const Center(child: Text('周辺店舗がありません'));
        }
        return PageView.builder(
          controller: PageController(viewportFraction: 0.9),
          itemCount: stores.length,
          itemBuilder: (context, i) => _StoreCard(store: stores[i]),
        );
      },
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Store store;
  const _StoreCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  store.category.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.star, size: 16, color: scheme.tertiary),
              const SizedBox(width: 2),
              Text(
                '${(store.recommendWeight * 100).round()}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.tertiary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            store.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '🎁 ${store.benefit}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.place, size: 16, color: scheme.outline),
              const SizedBox(width: 4),
              Text(
                '徒歩圏 | 15分後にクーポン受取',
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
