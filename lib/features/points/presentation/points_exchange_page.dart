import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';
import '../domain/exchange_item.dart';
import '../providers/exchange_providers.dart';
import '../providers/points_providers.dart';
import 'exchange_confirm_sheet.dart';
import 'exchange_history_page.dart';

class PointsExchangePage extends ConsumerStatefulWidget {
  const PointsExchangePage({super.key});

  @override
  ConsumerState<PointsExchangePage> createState() =>
      _PointsExchangePageState();
}

class _PointsExchangePageState extends ConsumerState<PointsExchangePage> {
  ExchangeCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final points = ref.watch(pointsProvider);
    final catalog = ref.watch(exchangeCatalogProvider);
    final filtered = _filter == null
        ? catalog
        : catalog.where((i) => i.category == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('ポイント交換'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '交換履歴',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const ExchangeHistoryPage(),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _BalanceCard(points: points),
            ),
            _CategoryStrip(
              selected: _filter,
              onChanged: (c) => setState(() => _filter = c),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final item = filtered[i];
                  return _ItemTile(
                    item: item,
                    enabled: points >= item.costPoints,
                    onTap: () => _onTap(item),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onTap(ExchangeItem item) async {
    final ok = await ExchangeConfirmSheet.show(context, item);
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.title} と交換しました')),
      );
    }
  }
}

class _BalanceCard extends StatelessWidget {
  final int points;
  const _BalanceCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E7CF6), Color(0xFF7C5CFF)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x332E7CF6),
            blurRadius: 24,
            spreadRadius: -8,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '現在の残高',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$points',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'pt',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryStrip extends StatelessWidget {
  final ExchangeCategory? selected;
  final ValueChanged<ExchangeCategory?> onChanged;
  const _CategoryStrip({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip(context, 'すべて', selected == null, () => onChanged(null)),
          for (final c in ExchangeCategory.values) ...[
            const SizedBox(width: 6),
            _chip(context, c.label, selected == c, () => onChanged(c)),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    bool isActive,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isActive
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isActive
                    ? AppColors.accent
                    : context.subtleBorder,
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: isActive ? AppColors.accent : context.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final ExchangeItem item;
  final bool enabled;
  final VoidCallback onTap;

  const _ItemTile({
    required this.item,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: GlassDecoration.light(context, radius: 18),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.55,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
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
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            )),
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.textSecondary,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: item.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${item.costPoints} pt',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: item.accent,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
