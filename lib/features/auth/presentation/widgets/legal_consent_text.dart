import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/legal_links.dart';
import '../../../../core/theme/app_colors.dart';

/// アカウント作成/続行の入口に出す、利用規約・プライバシーポリシーへの
/// みなし同意テキスト。規約名はタップで外部ブラウザに開く。
///
/// 明示チェックボックスではなく「続行すると同意したものとみなす」方式。
/// 主要アプリで一般的でストア審査でも許容される。法務要件で明示同意が必要なら
/// チェックボックス方式に差し替える。
class LegalConsentText extends StatelessWidget {
  const LegalConsentText({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodySmall?.copyWith(
      color: context.textSecondary,
      height: 1.5,
    );
    final link = base?.copyWith(
      color: AppColors.accent,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('続行すると', style: base),
        _LinkText(label: '利用規約', url: kTermsOfServiceUrl, style: link),
        Text('と', style: base),
        _LinkText(label: 'プライバシーポリシー', url: kPrivacyPolicyUrl, style: link),
        Text('に同意したものとみなされます', style: base),
      ],
    );
  }
}

class _LinkText extends StatelessWidget {
  final String label;
  final String url;
  final TextStyle? style;

  const _LinkText({required this.label, required this.url, this.style});

  Future<void> _open() async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: Text(label, style: style),
    );
  }
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
