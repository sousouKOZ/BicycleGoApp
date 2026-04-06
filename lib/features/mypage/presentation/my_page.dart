import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../points/providers/points_providers.dart';

class MyPage extends ConsumerWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pointsProvider);
    final ownedCoupons = [
      _OwnedCoupon(title: 'ドリンク無料（S）', expires: 'あと7日'),
      _OwnedCoupon(title: 'カフェ 200円引き', expires: 'あと3日'),
      _OwnedCoupon(title: 'コンビニ 50円引き', expires: 'あと12時間'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _PointsCard(points: points),
          const SizedBox(height: 12),
          _SectionHeader(
            title: '取得済みクーポン',
            subtitle: '使用前のクーポンを表示（後でフィルタ可能）',
          ),
          const SizedBox(height: 8),
          ...ownedCoupons.map((c) => _OwnedCouponTile(coupon: c)),
          const SizedBox(height: 18),
          _SectionHeader(
            title: 'メニュー',
            subtitle: '後で設定系を追加できます',
          ),
          const SizedBox(height: 8),
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('駐輪履歴（後で実装）'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {},
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('設定（後で実装）'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
              onPressed: () {
                // TODO: ポイント交換画面へ
              },
              child: const Text('交換する'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnedCouponTile extends StatelessWidget {
  final _OwnedCoupon coupon;
  const _OwnedCouponTile({required this.coupon});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.confirmation_number_outlined),
        title: Text(coupon.title),
        subtitle: Text('期限：${coupon.expires}'),
        trailing: ElevatedButton(
          onPressed: () {
            // TODO: クーポン使用
          },
          child: const Text('使う'),
        ),
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
        Text(subtitle,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
      ],
    );
  }
}

class _OwnedCoupon {
  final String title;
  final String expires;
  _OwnedCoupon({required this.title, required this.expires});
}
