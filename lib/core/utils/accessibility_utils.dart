import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Accessibility utilities for motion, animation, and visual preferences.
abstract final class AccessibilityUtils {
  /// Global toggle for app animations (defaults to true).
  /// Synchronized with user settings via SettingsNotifier / animationsEnabledProvider.
  static bool animationsEnabled = true;

  /// Returns `true` if animations are enabled by the user AND NOT requested reduced motion.
  static bool shouldAnimate(BuildContext context) =>
      animationsEnabled && !MediaQuery.of(context).disableAnimations;

  /// Returns the appropriate animation duration respecting reduced motion.
  static Duration animationDuration(BuildContext context, Duration normal) =>
      shouldAnimate(context) ? normal : Duration.zero;

  /// Returns the appropriate animation curve respecting reduced motion.
  static Curve animationCurve(BuildContext context, Curve normal) =>
      shouldAnimate(context) ? normal : Curves.linear;

  /// Encode a JSON map safely (reusable helper).
  static String encodeJson(Map<String, dynamic> map) => jsonEncode(map);

  /// Decode a JSON string to a map safely.
  static Map<String, dynamic> decodeJson(String json) =>
      jsonDecode(json) as Map<String, dynamic>;
}

/// Extension methods for clean, high-performance animations that automatically
/// respect [AccessibilityUtils.shouldAnimate].
///
/// On low-end devices or when animations are toggled OFF in settings,
/// these methods return [this] immediately without creating any controllers,
/// tickers, or extra render objects.
extension AccessibleAnimationExtension on Widget {
  /// Conditionally applies staggered fade & slide entrance animation.
  Widget animateFadeSlide(
    BuildContext context, {
    int index = 0,
    Duration duration = const Duration(milliseconds: 320),
    Offset slideOffset = const Offset(0, 0.04),
  }) {
    if (!AccessibilityUtils.shouldAnimate(context)) return this;
    final cappedIndex = index < 0 ? 0 : (index > 8 ? 8 : index);
    final delay = Duration(milliseconds: cappedIndex * 40);
    return animate(delay: delay)
        .fadeIn(duration: duration, curve: Curves.easeOutCubic)
        .slide(
          begin: slideOffset,
          end: Offset.zero,
          duration: duration,
          curve: Curves.easeOutCubic,
        );
  }

  /// Conditionally applies looping shimmer animation on skeleton loading widgets.
  Widget animateShimmer(
    BuildContext context, {
    Color? color,
    Duration duration = const Duration(milliseconds: 1200),
    Duration delay = Duration.zero,
  }) {
    if (!AccessibilityUtils.shouldAnimate(context)) return this;
    final shimmerColor = color ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.08);
    return animate(onPlay: (controller) => controller.repeat()).shimmer(
      duration: duration,
      delay: delay,
      color: shimmerColor,
    );
  }

  /// Conditionally applies subtle scale & pop micro-animation for interactive elements like FAB.
  Widget animateScalePop(
    BuildContext context, {
    Duration duration = const Duration(milliseconds: 300),
    Duration delay = Duration.zero,
  }) {
    if (!AccessibilityUtils.shouldAnimate(context)) return this;
    return animate(delay: delay)
        .scale(
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          duration: duration,
          curve: Curves.easeOutBack,
        )
        .fadeIn(duration: duration);
  }
}
