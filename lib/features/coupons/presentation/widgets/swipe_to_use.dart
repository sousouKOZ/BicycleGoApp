import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';

/// 会計時にスタッフ面前でスライドして消込むための確定ボタン。
///
/// 段階を踏んで「確定した」ことが一目で伝わるよう、次の流れで状態が変化する:
///   1. ドラッグ中 … 丸い矢印が右へ進むにつれてバー全体が満たされる
///   2. 消込中 …… しきい値まで滑らせると [onCompleted] を待つ間「消込中…」表示
///   3. 完了 …… 矢印がチェックに変わって軽くバウンドし、haptic を一度返す
///
/// 祝祭感より「確定 / 使用済み / 再利用不可」を優先するため、派手な全画面演出は持たない。
class SwipeToUse extends StatefulWidget {
  final String label;
  final String completedLabel;
  final String runningLabel;
  final bool enabled;
  final Future<void> Function() onCompleted;

  const SwipeToUse({
    super.key,
    required this.onCompleted,
    this.label = 'スワイプして使用',
    this.completedLabel = '使用済み',
    this.runningLabel = '消込中…',
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

  /// 完了の瞬間にチェックを弾ませ、背後でリングを広げるためのコントローラ。
  late final AnimationController _bounce;
  late final Animation<double> _bounceScale;
  late final Animation<double> _ringProgress;

  @override
  void initState() {
    super.initState();
    _bounce = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    // チェックが弾むように現れる。
    _bounceScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _bounce,
        curve: const Interval(0.0, 0.65, curve: Curves.elasticOut),
      ),
    );
    // チェック背後で広がりながら薄れていくリング（旧オーバーレイの要素）。
    _ringProgress = CurvedAnimation(parent: _bounce, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  Future<void> _onDragEnd(double maxDx) async {
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
        // 完了の確定感を触覚でも一度だけ返す。
        HapticFeedback.mediumImpact();
        _bounce.forward(from: 0);
      } catch (_) {
        if (!mounted) return;
        // 失敗時はスワイプを巻き戻して再操作できるようにする。
        setState(() {
          _offset = 0;
          _running = false;
        });
      }
    } else {
      setState(() => _offset = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEnabled = widget.enabled && !_completed && !_running;

    return LayoutBuilder(
      builder: (context, constraints) {
        const thumbSize = 56.0;
        final maxDx = constraints.maxWidth - thumbSize - 8;
        final progress = maxDx <= 0 ? 0.0 : (_offset / maxDx).clamp(0.0, 1.0);
        final filled = _completed || _running;
        final trackColor = filled
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
                  .withValues(alpha: filled ? 1 : 0.35 + 0.35 * progress),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.accent.withValues(alpha: filled ? 0.3 : 0.12),
                blurRadius: 20,
                spreadRadius: -6,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            // 完了時のリングがバーの外側へ気持ちよく広がれるよう、はみ出しを許可する。
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // 中央ラベル。ドラッグ中はサムが進むほど薄れ、消込中/完了では明示する。
              if (filled)
                _CenterLabel(
                  icon: _completed ? Icons.check_rounded : null,
                  text: _completed ? widget.completedLabel : widget.runningLabel,
                  color: Colors.white,
                  showSpinner: _running,
                )
              else
                AnimatedOpacity(
                  opacity: 1 - progress,
                  duration: const Duration(milliseconds: 120),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.accent.withValues(alpha: 0.45)),
                      const SizedBox(width: 2),
                      Text(
                        widget.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.accent,
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
                            _offset = (_offset + d.delta.dx).clamp(0.0, maxDx);
                          });
                        }
                      : null,
                  onHorizontalDragEnd:
                      isEnabled ? (_) => _onDragEnd(maxDx) : null,
                  child: SizedBox(
                    width: thumbSize,
                    height: thumbSize,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // チェック背後で広がって消えるリング。
                        if (_completed)
                          AnimatedBuilder(
                            animation: _ringProgress,
                            builder: (context, _) => CustomPaint(
                              size: const Size.square(thumbSize * 2),
                              painter: _RingPainter(progress: _ringProgress.value),
                            ),
                          ),
                        AnimatedContainer(
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
                                      AppColors.accent,
                                      AppColors.accentAlt,
                                    ],
                                  ),
                            color: _completed ? Colors.white : null,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.accent.withValues(alpha: 0.35),
                                blurRadius: 14,
                                spreadRadius: -2,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: _ThumbIcon(
                            completed: _completed,
                            running: _running,
                            bounceScale: _bounceScale,
                          ),
                        ),
                      ],
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

/// 消込中・完了時にバー中央へ出すラベル。完了ではチェックを前置する。
class _CenterLabel extends StatelessWidget {
  final IconData? icon;
  final String text;
  final Color color;
  final bool showSpinner;

  const _CenterLabel({
    required this.icon,
    required this.text,
    required this.color,
    required this.showSpinner,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (showSpinner) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(
                color.withValues(alpha: 0.9),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
        ],
        Text(
          text,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

/// サムのアイコン。完了時はチェックがバウンドして「確定」を伝える。
class _ThumbIcon extends StatelessWidget {
  final bool completed;
  final bool running;
  final Animation<double> bounceScale;

  const _ThumbIcon({
    required this.completed,
    required this.running,
    required this.bounceScale,
  });

  @override
  Widget build(BuildContext context) {
    if (running) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2.6,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
        ),
      );
    }
    if (completed) {
      return ScaleTransition(
        scale: bounceScale,
        child: const Icon(Icons.check_rounded,
            color: AppColors.accent, size: 28),
      );
    }
    return const Icon(Icons.arrow_forward_rounded,
        color: Colors.white, size: 26);
  }
}

/// 完了したチェックの背後で広がりながら薄れていくリング。
/// 旧消込オーバーレイの「広がるリング」要素をスワイプ完了の場に取り込んだもの。
class _RingPainter extends CustomPainter {
  final double progress;
  const _RingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final radius = 26 + (maxRadius - 26) * progress;
    final fade = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * fade + 1
      ..color = AppColors.accent.withValues(alpha: 0.5 * fade);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// Copyright (c) 2026 小塩颯汰
// Released under the MIT License.
