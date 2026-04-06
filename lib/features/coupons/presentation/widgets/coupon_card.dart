import 'package:flutter/material.dart';

class CouponCard extends StatelessWidget {
  final String title;

  const CouponCard({required this.title});

  @override
  Widget build(BuildContext context) => Card(child: Padding(
    padding: const EdgeInsets.all(12.0),
    child: Text(title),
  ));
}
