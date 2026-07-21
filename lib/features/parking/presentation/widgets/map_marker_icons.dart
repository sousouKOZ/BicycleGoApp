import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/domain/parking_lot.dart';

/// Google Maps の標準マーカーは Color ではなく hue 指定のため、
/// [UsageLevel] からマーカー用の hue に変換する。
double usageMarkerHue(UsageLevel level) {
  switch (level) {
    case UsageLevel.high:
      return BitmapDescriptor.hueRed;
    case UsageLevel.mid:
      return BitmapDescriptor.hueOrange;
    case UsageLevel.low:
      return BitmapDescriptor.hueGreen;
  }
}

/// 円形背景 + アイコンのマーカー画像（現在地表示用）を描画する。
Future<BitmapDescriptor> createCircleIconMarker({
  required IconData icon,
  required Color backgroundColor,
  Color iconColor = Colors.white,
}) async {
  const iconSize = 23.0;
  const padding = 10.0;
  final imageSize = (iconSize + padding * 2).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(imageSize / 2, imageSize / 2);

  final background = Paint()..color = backgroundColor;
  canvas.drawCircle(center, imageSize / 2.0, background);

  final textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: iconSize,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: iconColor,
      ),
    ),
  )..layout();

  final iconOffset = Offset(
    center.dx - textPainter.width / 2,
    center.dy - textPainter.height / 2,
  );
  textPainter.paint(canvas, iconOffset);

  final picture = recorder.endRecording();
  final image = await picture.toImage(imageSize, imageSize);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

/// 値札（タグ）型のクーポンマーカー画像を描画する。
Future<BitmapDescriptor> createCouponMarker() async {
  const tagSize = 24.0;
  const padding = 7.0;
  final imageSize = (tagSize + padding * 2).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final width = imageSize.toDouble();
  final height = imageSize.toDouble();

  final tagPath = Path();
  final bodyRect = Rect.fromLTWH(
      padding, padding * 0.6, width - padding * 1.8, height - padding * 1.2);
  const radius = Radius.circular(6);
  tagPath.addRRect(RRect.fromRectAndCorners(
    bodyRect,
    topLeft: radius,
    topRight: const Radius.circular(4),
    bottomLeft: radius,
    bottomRight: const Radius.circular(4),
  ));

  final tipStartY = bodyRect.top + bodyRect.height * 0.25;
  final tipEndY = bodyRect.bottom - bodyRect.height * 0.25;
  final tipPoint = Offset(width - padding * 0.2, height / 2);
  final tipPath = Path()
    ..moveTo(bodyRect.right, tipStartY)
    ..lineTo(tipPoint.dx, tipPoint.dy)
    ..lineTo(bodyRect.right, tipEndY)
    ..close();

  final shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.25)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);
  canvas.drawPath(tagPath.shift(const Offset(0, 2)), shadowPaint);
  canvas.drawPath(tipPath.shift(const Offset(0, 2)), shadowPaint);

  final tagPaint = Paint()..color = const Color(0xFFE53935);
  canvas.drawPath(tagPath, tagPaint);
  canvas.drawPath(tipPath, tagPaint);

  final holePaint = Paint()..color = Colors.white;
  canvas.drawCircle(
    Offset(bodyRect.left + 5, bodyRect.center.dy),
    2,
    holePaint,
  );

  final textPainter = TextPainter(
    textDirection: TextDirection.ltr,
    text: TextSpan(
      text: String.fromCharCode(Icons.local_offer.codePoint),
      style: TextStyle(
        fontSize: 16,
        fontFamily: Icons.local_offer.fontFamily,
        package: Icons.local_offer.fontPackage,
        color: Colors.white,
      ),
    ),
  )..layout();
  textPainter.paint(
    canvas,
    Offset(
      bodyRect.center.dx - textPainter.width / 2 + 1.5,
      bodyRect.center.dy - textPainter.height / 2,
    ),
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(imageSize, imageSize);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
