import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
import '../../parking/domain/parking_session.dart';
import '../../parking/providers/session_providers.dart';
import '../../stores/domain/store.dart';
import '../../stores/providers/store_providers.dart';
import '../data/notification_service.dart';

class SessionTimerPage extends ConsumerStatefulWidget {
  const SessionTimerPage({super.key});

  @override
  ConsumerState<SessionTimerPage> createState() => _SessionTimerPageState();
}

class _SessionTimerPageState extends ConsumerState<SessionTimerPage> {
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

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
      return const Scaffold(
        body: SafeArea(
          child: Center(child: Text('有効なセッションがありません')),
        ),
      );
    }

    final total = ParkingSession.earnThreshold.inSeconds;
    final secondsPassed = _elapsed.inSeconds.clamp(0, total);
    final secondsLeft = (total - secondsPassed).clamp(0, total);
    final progress = secondsPassed / total;
    final mm = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final ss = (secondsLeft % 60).toString().padLeft(2, '0');
    final isAchieving = session.status == ParkingSessionStatus.achieved ||
        secondsPassed >= total;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '計測中',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: '最小化',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _CountdownCard(
                progress: progress,
                mm: mm,
                ss: ss,
                isAchieving: isAchieving,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 4,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '待機中に行ってみる？',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '15分達成でクーポンを自動発行します',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Expanded(child: _StoreCarousel()),
              const SizedBox(height: 8),
              TextButton(
                onPressed: isAchieving ? null : _cancelSession,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.danger,
                ),
                child: Text(
                  '計測を中止する',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('中止する'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(apiClientProvider).endSession(session.id);
    await NotificationService.instance.cancelSessionReminders();
    ref.read(activeSessionProvider.notifier).state = null;
    ref.read(activeParkingInfoProvider.notifier).state = null;
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF2E7CF6),
            Color(0xFF7C5CFF),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x402E7CF6),
            blurRadius: 40,
            spreadRadius: -10,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            width: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 180,
                  width: 180,
                  child: CircularProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    strokeWidth: 10,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    color: Colors.white,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isAchieving ? '発行中…' : '$mm:$ss',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isAchieving ? 'クーポンを選定中' : 'クーポン獲得まで',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_bike_rounded,
                    size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  '停めてスキャン完了 → 街を楽しむだけ',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
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
          controller: PageController(viewportFraction: 0.88),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      padding: const EdgeInsets.all(20),
      decoration: GlassDecoration.accentCard(context, radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: context.subtleBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  store.category.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const Spacer(),
              Icon(Icons.star_rounded,
                  size: 16, color: AppColors.warning),
              const SizedBox(width: 2),
              Text(
                '${(store.recommendWeight * 100).round()}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: context.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            store.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.local_offer_rounded,
                    size: 14, color: AppColors.accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    store.benefit,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(Icons.place_outlined,
                  size: 14, color: context.textSecondary),
              const SizedBox(width: 4),
              Text(
                '徒歩圏 · 15分後にクーポン受取',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
