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
    builder: builder,
  );
}
