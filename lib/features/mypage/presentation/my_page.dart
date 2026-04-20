import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coupons/domain/coupon.dart';
import '../../coupons/providers/coupon_providers.dart';
import '../../points/providers/points_providers.dart';

class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pointsProvider);
    final asyncCoupons = ref.watch(userCouponsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _PointsCard(points: points),
          const SizedBox(height: 12),
          const _SectionHeader(
            title: '利用可能クーポン',
            subtitle: '15分駐輪で自動発行されたクーポン',
          ),
          const SizedBox(height: 8),
          asyncCoupons.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('読み込み失敗: $e'),
            data: (list) {
              final usable =
                  list.where((c) => c.status == CouponStatus.owned && !c.isExpired).toList();
              if (usable.isEmpty) {
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('利用可能なクーポンはありません'),
                  ),
                );
              }
              return Column(
                children: usable.map((c) => _OwnedCouponTile(coupon: c)).toList(),
              );
            },
          ),
          const SizedBox(height: 18),
          const _SectionHeader(
            title: 'メニュー',
            subtitle: '',
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('駐輪履歴（準備中）'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('設定（準備中）'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  final int points;
  const _PointsCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.stars, size: 34),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('現在のポイント', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    '$points pt',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {},
              child: const Text('交換する'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnedCouponTile extends StatelessWidget {
  final Coupon coupon;
  const _OwnedCouponTile({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final expires = coupon.expiresAt;
    final expiresLabel =
        '${expires.month}/${expires.day.toString().padLeft(2, '0')}まで';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.confirmation_number_outlined),
        title: Text(coupon.benefit),
        subtitle: Text('${coupon.storeName}・$expiresLabel'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        if (subtitle.isNotEmpty)
          Text(subtitle,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor)),
      ],
    );
  }
}
