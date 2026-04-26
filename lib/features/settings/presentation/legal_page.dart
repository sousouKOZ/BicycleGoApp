import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 利用規約・プライバシーポリシーなどの静的テキストページの共通レイアウト。
class LegalPage extends StatelessWidget {
  final String title;
  final String lastUpdated;
  final List<LegalSection> sections;

  const LegalPage({
    super.key,
    required this.title,
    required this.lastUpdated,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Text(
              title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '最終更新: $lastUpdated',
              style: theme.textTheme.labelMedium?.copyWith(
                color: context.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(height: 18),
              Text(
                '${i + 1}. ${sections[i].heading}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sections[i].body,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: context.textPrimary,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LegalSection {
  final String heading;
  final String body;
  const LegalSection({required this.heading, required this.body});
}

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalPage(
      title: '利用規約',
      lastUpdated: '2026-04-25',
      sections: [
        LegalSection(
          heading: '本規約の適用',
          body: '本規約は、BicycleGo（以下「本サービス」）の利用に関する条件を、'
              '本サービスを提供する運営者と利用者との間で定めるものです。'
              '利用者は本サービスを利用することにより、本規約に同意したものとみなされます。',
        ),
        LegalSection(
          heading: 'サービス内容',
          body: '本サービスは、提携駐輪場の空き情報の提供、'
              '駐輪セッションの計測、提携店舗のクーポン発行および交換機能を提供するものです。'
              '提携店舗・駐輪場・特典内容は予告なく変更されることがあります。',
        ),
        LegalSection(
          heading: 'クーポンおよびポイント',
          body: 'クーポンは発行から所定の期間内のみ利用可能で、現金との交換はできません。'
              'ポイントの有効期限・交換可能商品は本サービス内で表示するものに従います。'
              '不正取得が確認された場合、運営者はクーポン・ポイントを無効化できるものとします。',
        ),
        LegalSection(
          heading: '禁止事項',
          body: '利用者は以下の行為を行ってはなりません。\n'
              '・本サービスの運営を妨げる行為\n'
              '・他の利用者・提携店舗・第三者に不利益または損害を与える行為\n'
              '・不正な手段でクーポン・ポイントを取得する行為\n'
              '・本サービスを商業目的・営利目的で無断利用する行為',
        ),
        LegalSection(
          heading: '免責事項',
          body: '駐輪場の空き情報・経路情報・店舗情報の正確性について、運営者は保証しません。'
              '本サービスの利用により利用者または第三者に損害が生じた場合でも、'
              '運営者の故意または重過失による場合を除き、運営者は責任を負わないものとします。',
        ),
        LegalSection(
          heading: '規約の変更',
          body: '運営者は必要と判断した場合、本規約を変更することがあります。'
              '変更後の規約は本サービス内で表示した時点から効力を生じます。',
        ),
        LegalSection(
          heading: '準拠法および管轄裁判所',
          body: '本規約の解釈および適用は日本法に準拠します。'
              '本サービスに関して紛争が生じた場合、運営者所在地を管轄する裁判所を専属的合意管轄とします。',
        ),
      ],
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalPage(
      title: 'プライバシーポリシー',
      lastUpdated: '2026-04-25',
      sections: [
        LegalSection(
          heading: '取得する情報',
          body: '本サービスは利用にあたり以下の情報を取得します。\n'
              '・端末を識別するためのデバイスID（端末ローカルで生成）\n'
              '・現在地の緯度経度（駐輪場検索・GPS照合のため）\n'
              '・NFCタグの識別子（駐輪認証のため）\n'
              '・お気に入り・履歴・ニックネームなど利用者が入力・操作した情報',
        ),
        LegalSection(
          heading: '利用目的',
          body: '取得した情報は、以下の目的のためにのみ利用します。\n'
              '・駐輪場の検索・経路案内・空き情報の表示\n'
              '・駐輪セッションの計測およびクーポンの発行\n'
              '・サービス改善のための統計分析（個人を特定しない形で）',
        ),
        LegalSection(
          heading: '位置情報',
          body: '位置情報は端末上での処理および駐輪認証時のサーバー送信のみに利用し、'
              '広告配信・第三者提供は行いません。'
              '位置情報の利用はいつでも端末の設定アプリから無効化できます。',
        ),
        LegalSection(
          heading: '第三者提供',
          body: '法令に基づく場合を除き、利用者の同意なく第三者に個人情報を提供することはありません。'
              '提携店舗にはクーポン消込時に消込情報のみが共有されます（個人を特定する情報は含みません）。',
        ),
        LegalSection(
          heading: 'データの保存',
          body: '駐輪履歴・お気に入り・ポイント残高・ニックネームは端末ローカルに保存されます。'
              'アプリの削除によりこれらのデータは消去されます。'
              '将来的にアカウント連携機能を提供する際は、改めて同意を求めます。',
        ),
        LegalSection(
          heading: '通知',
          body: '駐輪セッションのリマインダ通知のために、'
              'OSの通知許可を求める場合があります。'
              '通知は端末の設定からいつでも無効化できます。',
        ),
        LegalSection(
          heading: 'お問い合わせ',
          body: '本ポリシーまたはプライバシーに関するお問い合わせは、'
              'アプリストアのレビューまたは運営者連絡先までお願いします。',
        ),
      ],
    );
  }
}
