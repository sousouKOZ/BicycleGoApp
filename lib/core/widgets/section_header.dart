import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// アクセントバー付きのセクション見出し（タイトル + 説明）。
class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  const SectionHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: 28,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: context.textPrimary,
                    )),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.textSecondary,
                      )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 大文字小見出し（設定・プロフィール等のグループラベル）。
class SectionLabel extends StatelessWidget {
  final String label;
  final EdgeInsetsGeometry padding;
  const SectionLabel({
    super.key,
    required this.label,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
      ),
    );
  }
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
