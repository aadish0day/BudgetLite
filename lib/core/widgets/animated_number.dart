import 'package:flutter/material.dart';

/// A widget that animates number changes by smoothly counting from the
/// previous value to the new target value.
///
/// Uses [TweenAnimationBuilder] with an easeOutCubic curve so balance
/// figures feel responsive and alive rather than snapping instantly.
class AnimatedNumber extends StatelessWidget {
  /// The target number to animate toward.
  final double value;

  /// Builder that receives the current interpolated value and returns a [Text]
  /// or other widget to display it.
  final Widget Function(BuildContext context, double animatedValue, Widget? child) builder;

  /// Duration of the animation. Default 600ms feels natural for financial figures.
  final Duration duration;

  /// Animation curve. Default [Curves.easeOutCubic] gives a decelerating feel.
  final Curve curve;

  const AnimatedNumber({
    super.key,
    required this.value,
    required this.builder,
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: curve,
      builder: builder,
    );
  }
}
