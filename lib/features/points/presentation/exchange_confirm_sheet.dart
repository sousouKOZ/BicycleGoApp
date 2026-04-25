import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
import '../../coupons/providers/coupon_providers.dart';
import '../../user/providers/user_providers.dart';
import '../domain/exchange_item.dart';
import '../domain/exchange_record.dart';
import '../providers/exchange_providers.dart';
import '../providers/points_providers.dart';

/// 交換確認シート。残高検証 → ポイント減算 → 履歴登録 を行う。
class ExchangeConfirmSheet extends ConsumerStatefulWidget {
  final ExchangeItem item;
  const ExchangeConfirmSheet({super.key, required this.item});

  static Future<bool?> show(BuildContext context, ExchangeItem item) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ExchangeConfirmSheet(item: item),
    );
  }

  @override
  ConsumerState<ExchangeConfirmSheet> createState() =>
      _ExchangeConfirmSheetState();
}

class _ExchangeConfirmSheetState extends ConsumerState<ExchangeConfirmSheet> {
  bool _running = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final points = ref.watch(pointsProvider);
    final remaining = points - item.costPoints;
    final isInsufficient = remaining < 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(item.icon, size: 24, color: item.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        )),
                    const SizedBox(height: 2),
                    Text(item.category.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(item.description,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          const SizedBox(height: 18),
          Container(
            decoration: GlassDecoration.light(context, radius: 16),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _row(context, '必要ポイント', '-${item.costPoints} pt',
                    color: AppColors.danger),
                const SizedBox(height: 10),
                _row(context, '現在の残高', '$points pt'),
                const SizedBox(height: 10),
                Divider(color: context.subtleBorder, height: 1),
                const SizedBox(height: 10),
                _row(
                  context,
                  '交換後の残高',
                  isInsufficient ? '不足: ${remaining}pt' : '$remaining pt',
                  color: isInsufficient ? AppColors.danger : AppColors.success,
                  emphasize: true,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w700,
                )),
          ],
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: (isInsufficient || _running) ? null : _exchange,
            child: _running
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    isInsufficient ? 'ポイントが足りません' : '交換する',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _running ? null : () => Navigator.of(context).pop(false),
            child: Text('キャンセル',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: context.textSecondary,
                  fontWeight: FontWeight.w700,
                )),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    Color? color,
    bool emphasize = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.w700,
              )),
        ),
        Text(
          value,
          style: emphasize
              ? theme.textTheme.titleMedium?.copyWith(
                  color: color ?? context.textPrimary,
                  fontWeight: FontWeight.w900,
                )
              : theme.textTheme.bodyMedium?.copyWith(
                  color: color ?? context.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
        ),
      ],
    );
  }

  Future<void> _exchange() async {
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final pointsNotifier = ref.read(pointsProvider.notifier);
      final current = pointsNotifier.state;
      if (current < widget.item.costPoints) {
        setState(() {
          _error = 'ポイントが不足しています';
          _running = false;
        });
        return;
      }

      final api = ref.read(apiClientProvider);
      final userId = ref.read(currentUserIdProvider);
      await api.issueExchangeCoupon(
        userId: userId,
        exchangeItemId: widget.item.id,
        displayStoreName: 'ポイント交換特典',
        title: widget.item.description,
        benefit: widget.item.title,
        validity: const Duration(days: 30),
      );

      pointsNotifier.state = current - widget.item.costPoints;
      await ref.read(exchangeHistoryProvider.notifier).add(
            ExchangeRecord(
              id: 'exch-${DateTime.now().millisecondsSinceEpoch}',
              itemId: widget.item.id,
              itemTitle: widget.item.title,
              costPoints: widget.item.costPoints,
              exchangedAt: DateTime.now(),
            ),
          );
      ref.invalidate(userCouponsProvider);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '交換に失敗しました: $e';
        _running = false;
      });
    }
  }
}
