import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/glass_decoration.dart';

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  static const _faqs = <_Faq>[
    _Faq(
      q: 'クーポンはどうすればもらえますか？',
      a: '提携駐輪場に駐輪してNFCタグを「スキャン」すると計測が始まり、'
          '15分経過すると近隣店舗のクーポンが自動で発行されます。'
          '15分経過前に出庫した場合はクーポンは発行されません。',
    ),
    _Faq(
      q: '「あとで使う」を選んだクーポンはどこで確認できますか？',
      a: 'マイページまたはクーポンタブの「利用可能」セクションに表示されます。'
          'カードをタップすると詳細ページが開き、店舗で会計時にスワイプして消込できます。',
    ),
    _Faq(
      q: 'クーポンを獲得した後、駐輪場の空き情報はいつ更新されますか？',
      a: 'クーポン獲得後にミニバーから「自転車を出す」操作を行うと'
          '駐輪場の空き情報が更新されます。出庫操作を忘れると空き状況が古いままになります。',
    ),
    _Faq(
      q: 'NFC対応していない端末でも使えますか？',
      a: '一部のAndroid端末などNFC非対応の場合は自動でデモモードに切り替わり、'
          'GPS位置情報のみで認証が行われます。',
    ),
    _Faq(
      q: 'ポイントはどう貯まりますか？',
      a: '15分達成1回につき10ポイントが貯まります。'
          '貯まったポイントはマイページの「交換する」から好きな特典と交換できます。',
    ),
    _Faq(
      q: '位置情報を許可したくありません',
      a: '位置情報なしでも地図閲覧は可能ですが、現在地からの距離表示・'
          'NFC認証時のGPS照合・経路案内は利用できません。'
          'いつでも端末の設定アプリから変更できます。',
    ),
    _Faq(
      q: '機種変更したらデータは引き継がれますか？',
      a: '現在は端末ローカルにすべて保存しています。アカウント連携機能は準備中のため、'
          '機種変更ではポイント・履歴・お気に入りはリセットされます。',
    ),
    _Faq(
      q: 'クーポンの有効期限を過ぎたらどうなりますか？',
      a: '期限切れのクーポンは「期限切れ」セクションに移動し、利用できなくなります。'
          '期限延長や復活はできませんのでご注意ください。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ヘルプ・FAQ'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: GlassDecoration.light(context, radius: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.help_outline_rounded,
                        color: AppColors.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'よくある質問にお答えします。\n解決しない場合はストアレビューよりお知らせください。',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(_faqs.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FaqTile(faq: _faqs[i]),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Faq {
  final String q;
  final String a;
  const _Faq({required this.q, required this.a});
}

class _FaqTile extends StatelessWidget {
  final _Faq faq;
  const _FaqTile({required this.faq});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: GlassDecoration.light(context, radius: 14),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          leading: Icon(Icons.question_answer_rounded,
              color: AppColors.accent, size: 20),
          title: Text(
            faq.q,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                faq.a,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
