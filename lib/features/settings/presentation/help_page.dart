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
      a: '自転車をスタンドから取り出すと自動で出庫が検知され、'
          '駐輪場の空き情報が更新されます。アプリでの操作は不要です。',
    ),
    _Faq(
      q: 'NFC対応していない端末でも使えますか？',
      a: '駐輪認証にはNFCのタッチが必要なため、NFC非対応の端末では'
          '駐輪認証（およびクーポンの獲得）はご利用いただけません。'
          '地図の閲覧や駐輪場の検索など、NFCを使わない機能はご利用いただけます。',
    ),
    _Faq(
      q: 'ポイントはどう貯まりますか？',
      a: '15分達成1回につき10ポイントが貯まります。'
          '貯まったポイントはマイページの「交換する」から好きな特典と交換できます。',
    ),
    _Faq(
      q: '位置情報を許可したくありません',
      a: '位置情報なしでも地図閲覧は可能ですが、現在地からの距離表示・'
          '近隣店舗のレコメンド・経路案内は利用できません。'
          '駐輪認証には位置情報を使用しないため、認証はそのままご利用いただけます。'
          'いつでも端末の設定アプリから変更できます。',
    ),
    _Faq(
      q: 'アカウント登録は必要ですか？',
      a: 'メールアドレスでの登録なしでも「ゲスト」として主な機能をご利用いただけます。'
          'ただしポイントや履歴を機種変更後も引き継ぎたい場合は、'
          'メールアドレスとパスワードでのアカウント登録をおすすめします。',
    ),
    _Faq(
      q: 'ゲストで貯めたポイントは登録後も残りますか？',
      a: 'はい。ゲストのまま貯めたポイント・駐輪履歴・クーポンは、'
          'そのままメールアドレスでアカウント登録（昇格）すれば引き継がれます。'
          '登録は設定やマイページのアカウントメニューから行えます。',
    ),
    _Faq(
      q: '機種変更したらデータは引き継がれますか？',
      a: 'メールアドレスで登録したアカウントにログインすれば、'
          'ポイント・駐輪履歴・獲得クーポンはサーバーから引き継がれます。'
          'お気に入りは端末内に保存されるため引き継がれません。'
          'ゲストのままご利用の場合はデータを引き継げませんのでご注意ください。',
    ),
    _Faq(
      q: 'パスワードを忘れてしまいました',
      a: 'ログイン画面の「パスワードをお忘れですか？」から、'
          '登録したメールアドレス宛に再設定用リンクをお送りします。'
          'メール内のリンクを開き、新しいパスワードを設定してください。',
    ),
    _Faq(
      q: '退会するとデータはどうなりますか？',
      a: 'アカウントを削除（退会）すると、サーバー上のポイント・駐輪履歴・'
          'クーポンなどアカウントに紐づくデータは削除され、元に戻すことはできません。'
          '退会は設定のアカウントメニューから行えます。',
    ),
    _Faq(
      q: '通知（プッシュ）は何のために届きますか？',
      a: '長時間駐輪のお知らせや駐輪セッションに関するリマインダのために通知をお送りします。'
          '通知が不要な場合は、端末の設定アプリからいつでも無効化できます。',
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

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
