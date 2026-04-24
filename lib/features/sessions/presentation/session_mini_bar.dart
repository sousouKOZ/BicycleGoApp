import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../parking/domain/parking_session.dart';
import '../../parking/providers/session_providers.dart';
import 'session_timer_page.dart';

class SessionMiniBar extends ConsumerStatefulWidget {
  const SessionMiniBar({super.key});

  @override
  ConsumerState<SessionMiniBar> createState() => _SessionMiniBarState();
}

class _SessionMiniBarState extends ConsumerState<SessionMiniBar> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeSessionProvider);
    if (session == null ||
        session.authenticatedAt == null ||
        session.status == ParkingSessionStatus.completed ||
        session.status == ParkingSessionStatus.expired) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final total = ParkingSession.earnThreshold.inSeconds;
    final elapsed = DateTime.now()
        .difference(session.authenticatedAt!)
        .inSeconds
        .clamp(0, total);
    final left = total - elapsed;
    final progress = elapsed / total;
    final achieved = session.status == ParkingSessionStatus.achieved;
    final mm = (left ~/ 60).toString().padLeft(2, '0');
    final ss = (left % 60).toString().padLeft(2, '0');

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2E7CF6), Color(0xFF7C5CFF)],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x332E7CF6),
                blurRadius: 18,
                spreadRadius: -6,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: InkWell(
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                MaterialPageRoute(
                    builder: (_) => const SessionTimerPage()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          achieved
                              ? Icons.celebration_rounded
                              : Icons.timer_outlined,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              achieved ? 'クーポン発行中' : '駐輪計測中',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              achieved ? '少々お待ちください' : '残り $mm:$ss',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 5,
                      backgroundColor: Colors.white.withValues(alpha: 0.24),
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
