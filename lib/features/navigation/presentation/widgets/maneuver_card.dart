import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/nav_step.dart';

/// 画面上部の「次の曲がり角」カード。
///
/// 自転車走行中にちらっと見るものなので、距離と矢印だけで判断できる字面にする。
/// 配色はテーマに依存せずナビ色で固定（明るい屋外でのコントラストを優先）。
class ManeuverCard extends StatelessWidget {
  final NavManeuver maneuver;
  final String instruction;
  final double distanceMeters;
  final NavStep? followingStep;

  const ManeuverCard({
    super.key,
    required this.maneuver,
    required this.instruction,
    required this.distanceMeters,
    this.followingStep,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final following = followingStep;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF17325C),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(maneuver.icon, size: 34, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatDistanceMeters(distanceMeters),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      instruction,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (following != null) ...[
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: Colors.white.withValues(alpha: 0.16),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'その先',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  following.maneuver.icon,
                  size: 16,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    following.instruction,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
