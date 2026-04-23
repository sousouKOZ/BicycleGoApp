import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class SwipeToUse extends StatefulWidget {
  final String label;
  final String completedLabel;
  final bool enabled;
  final Future<void> Function() onCompleted;

  const SwipeToUse({
    super.key,
    required this.onCompleted,
    this.label = 'スワイプして使用',
    this.completedLabel = '使用済み',
    this.enabled = true,
  });

  @override
  State<SwipeToUse> createState() => _SwipeToUseState();
}

class _SwipeToUseState extends State<SwipeToUse>
    with SingleTickerProviderStateMixin {
  double _offset = 0;
  bool _completed = false;
  bool _running = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = widget.enabled && !_completed && !_running;

    return LayoutBuilder(
      builder: (context, constraints) {
        const thumbSize = 56.0;
        final maxDx = constraints.maxWidth - thumbSize - 8;
        final progress = maxDx <= 0 ? 0.0 : (_offset / maxDx).clamp(0.0, 1.0);
        final trackColor = _completed
            ? AppColors.accent
            : Color.lerp(
                AppColors.accent.withValues(alpha: 0.12),
                AppColors.accent.withValues(alpha: 0.28),
                progress,
              )!;

        return Container(
          height: thumbSize + 8,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.accent
                  .withValues(alpha: _completed ? 1 : 0.35 + 0.35 * progress),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent
                    .withValues(alpha: _completed ? 0.3 : 0.12),
                blurRadius: 20,
                spreadRadius: -6,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                opacity: 1 - progress,
                duration: const Duration(milliseconds: 120),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_completed) ...[
                      Icon(Icons.chevron_right_rounded,
                          size: 18,
                          color:
                              AppColors.accent.withValues(alpha: 0.45)),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      _completed ? widget.completedLabel : widget.label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _completed ? Colors.white : AppColors.accent,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 4 + _offset,
                child: GestureDetector(
                  onHorizontalDragUpdate: isEnabled
                      ? (d) {
                          setState(() {
                            _offset =
                                (_offset + d.delta.dx).clamp(0.0, maxDx);
                          });
                        }
                      : null,
                  onHorizontalDragEnd: isEnabled
                      ? (_) async {
                          if (_offset >= maxDx * 0.92) {
                            setState(() {
                              _offset = maxDx;
                              _running = true;
                            });
                            try {
                              await widget.onCompleted();
                              if (!mounted) return;
                              setState(() {
                                _completed = true;
                                _running = false;
                              });
                            } catch (_) {
                              if (!mounted) return;
                              setState(() {
                                _offset = 0;
                                _running = false;
                              });
                            }
                          } else {
                            setState(() => _offset = 0);
                          }
                        }
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      gradient: _completed
                          ? null
                          : const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF2E7CF6),
                                Color(0xFF7C5CFF),
                              ],
                            ),
                      color: _completed ? Colors.white : null,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withValues(alpha: 0.35),
                          blurRadius: 14,
                          spreadRadius: -2,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(
                      _completed
                          ? Icons.check_rounded
                          : _running
                              ? Icons.hourglass_top_rounded
                              : Icons.arrow_forward_rounded,
                      color: _completed ? AppColors.accent : Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
