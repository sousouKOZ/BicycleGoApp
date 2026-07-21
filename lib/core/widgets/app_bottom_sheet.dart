import 'package:flutter/material.dart';

/// アプリ標準のモーダルボトムシート
/// （スクロール対応 + ドラッグハンドル付き）を開く。
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // 端末下端のジェスチャー／ナビゲーションバー領域にシート内ボタンが
    // 被らないよう、下端のシステムインセットだけ SafeArea で確保する。
    builder: (context) => SafeArea(
      top: false,
      child: builder(context),
    ),
  );
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
