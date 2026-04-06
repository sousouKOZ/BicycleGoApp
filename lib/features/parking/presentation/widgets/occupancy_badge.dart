import 'package:flutter/material.dart';

class OccupancyBadge extends StatelessWidget {
  final int occupied;
  final int capacity;

  const OccupancyBadge({required this.occupied, required this.capacity});

  @override
  Widget build(BuildContext context) => Chip(
        label: Text('$occupied / $capacity'),
      );
}
