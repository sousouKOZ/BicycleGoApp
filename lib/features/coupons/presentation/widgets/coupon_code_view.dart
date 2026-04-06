import 'package:flutter/material.dart';

class CouponCodeView extends StatelessWidget {
  final String code;

  const CouponCodeView({required this.code});

  @override
  Widget build(BuildContext context) => SelectableText(code);
}
