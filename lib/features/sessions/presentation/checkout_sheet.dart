import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
import '../../parking/domain/parking_session.dart';
import '../../parking/providers/session_providers.dart';
import '../data/notification_service.dart';
import '../providers/session_history_providers.dart';

/// 出庫操作のボトムシート。
///
/// クーポン獲得後に「あとで使う（駐輪を続ける）」を選んだセッションを
/// ユーザーが自転車を出すタイミングで終了させる。
/// 履歴の completedAt を実際の出庫時刻に上書きし、API にも endSession を投げる。
class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const CheckoutSheet(),
    );
  }

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  Timer? _ticker;
  bool _confirming = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = ref.watch(activeSessionProvider);
    final parkingInfo = ref.watch(activeParkingInfoProvider);
    if (session == null || session.authenticatedAt == null) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('有効なセッションがありません')),
      );
    }

    final elapsed = DateTime.now().difference(session.authenticatedAt!);
    final mm = elapsed.inMinutes;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.directions_bike_rounded,
                    size: 22, color: AppColors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '自転車を出しますか？',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '駐輪場の空き情報を更新します',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            decoration: GlassDecoration.light(context, radius: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (parkingInfo != null) ...[
                  _row(context, '駐輪場', parkingInfo.parkingName),
                  const SizedBox(height: 10),
                ],
                _row(context, '駐輪開始', _formatTime(session.authenticatedAt!)),
                const SizedBox(height: 10),
                _row(context, '駐輪時間', _formatDuration(elapsed)),
                const SizedBox(height: 10),
                _row(context, 'ステータス',
                    mm >= 15 ? 'クーポン獲得済み' : 'クーポン未達成'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.success,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _confirming ? null : _checkout,
            icon: _confirming
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.logout_rounded, size: 18),
            label: Text(
              _confirming ? '処理中…' : '自転車を出す',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _confirming ? null : () => Navigator.of(context).pop(),
            child: Text(
              'まだ出さない',
              style: theme.textTheme.labelLarge?.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _checkout() async {
    setState(() => _confirming = true);
    final session = ref.read(activeSessionProvider);
    final completedAt = DateTime.now();
    try {
      if (session != null) {
        await ref.read(apiClientProvider).endSession(session.id);
        await ref
            .read(sessionHistoryProvider.notifier)
            .updateCompletedAt(session.id, completedAt);
      }
      await NotificationService.instance.cancelSessionReminders();
      ref.read(activeSessionProvider.notifier).state = session?.copyWith(
        status: ParkingSessionStatus.completed,
        exitedAt: completedAt,
      );
      ref.read(activeSessionProvider.notifier).state = null;
      ref.read(activeParkingInfoProvider.notifier).state = null;
    } finally {
      if (mounted) {
        setState(() => _confirming = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('お疲れさまでした！またのご利用をお待ちしています')),
        );
      }
    }
  }
}

String _formatTime(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.hour)}:${two(d.minute)}';
}

String _formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h >= 1) return '${h}時間 ${m}分';
  return '${m}分';
}
