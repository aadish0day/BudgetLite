import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A thin, elegant arc progress indicator — the signature visual motif of BudgetLite.
///
/// Replaces standard Material linear progress bars with a precise,
/// ledger-inspired circular arc. Supports two sizes:
/// - **Small** (size=32, stroke=4): inline category progress
/// - **Large** (size=64, stroke=6): goal / balance progress
///
/// The arc sweeps clockwise from the top (12 o'clock position).
/// Progress changes animate with a smooth easeOutCubic spring.
class ArcProgress extends StatelessWidget {
  const ArcProgress({
    super.key,
    required this.progress,
    required this.color,
    this.size = 48,
    this.strokeWidth = 4,
    this.center,
    this.showTrack = true,
  });

  /// Progress value from 0.0 to 1.0. Values outside [0,1] are clamped.
  final double progress;

  /// The color of the filled arc segment.
  final Color color;

  /// Total diameter of the arc circle. Default 48.
  final double size;

  /// Width of the arc stroke. Default 4.
  final double strokeWidth;

  /// Optional widget displayed in the centre of the ring.
  final Widget? center;

  /// Whether to show a subtle track behind the arc. Default true.
  final bool showTrack;

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: clamped),
        duration: 800.ms,
        curve: Curves.easeOutCubic,
        builder: (context, animatedProgress, child) {
          return CustomPaint(
            painter: _ArcPainter(
              progress: animatedProgress,
              color: color,
              strokeWidth: strokeWidth,
              showTrack: showTrack,
            ),
            child: center != null
                ? Padding(
                    padding: EdgeInsets.all(strokeWidth + 2),
                    child: FittedBox(fit: BoxFit.scaleDown, child: center),
                  )
                : null,
          );
        },
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.showTrack,
  });
  final double progress;
  final Color color;
  final double strokeWidth;
  final bool showTrack;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - (strokeWidth / 2);

    // Track circle (subtle background)
    if (showTrack) {
      final trackPaint = Paint()
        ..color = color.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, radius, trackPaint);
    }

    // Progress arc
    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14159 / 2, // start at top (12 o'clock)
        3.14159 * 2 * progress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
