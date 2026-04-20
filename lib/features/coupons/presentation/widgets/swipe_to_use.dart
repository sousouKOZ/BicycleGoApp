import 'package:flutter/material.dart';

/// 店舗スタッフの目視下でユーザ自身が操作する「スワイプto消込」バー。
/// 仕様§3.3 ユーザースワイプ型クーポン消込機能に対応。
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
    final scheme = theme.colorScheme;
    final isEnabled = widget.enabled && !_completed && !_running;

    return LayoutBuilder(
      builder: (context, constraints) {
        const thumbSize = 56.0;
        final maxDx = constraints.maxWidth - thumbSize - 8;
        final progress = maxDx <= 0 ? 0.0 : (_offset / maxDx).clamp(0.0, 1.0);

        return Container(
          height: thumbSize + 8,
          decoration: BoxDecoration(
            color: _completed
                ? scheme.primary
                : scheme.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: scheme.primary.withOpacity(_completed ? 1 : 0.5),
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                opacity: 1 - progress,
                duration: const Duration(milliseconds: 120),
                child: Text(
                  _completed ? widget.completedLabel : widget.label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: _completed ? scheme.onPrimary : scheme.primary,
                  ),
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
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: _completed ? scheme.onPrimary : scheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(
                      _completed
                          ? Icons.check
                          : _running
                              ? Icons.hourglass_top
                              : Icons.arrow_forward,
                      color: _completed ? scheme.primary : scheme.onPrimary,
                      size: 28,
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
