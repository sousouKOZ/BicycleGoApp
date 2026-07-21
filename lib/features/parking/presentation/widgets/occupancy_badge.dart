import 'package:flutter/material.dart';

class OccupancyBadge extends StatelessWidget {
  final int occupied;
  final int capacity;

  const OccupancyBadge({
    super.key,
    required this.occupied,
    required this.capacity,
  });

  @override
  Widget build(BuildContext context) => Chip(
        label: Text('$occupied / $capacity'),
      );
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
