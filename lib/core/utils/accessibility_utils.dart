import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Accessibility utilities for motion, animation, and visual preferences.
abstract final class AccessibilityUtils {
  /// Returns `true` if the user has NOT requested reduced motion.
  static bool shouldAnimate(BuildContext context) =>
      !MediaQuery.of(context).disableAnimations;

  /// Returns the appropriate animation duration respecting reduced motion.
  static Duration animationDuration(BuildContext context, Duration normal) =>
      shouldAnimate(context) ? normal : Duration.zero;

  /// Returns the appropriate animation curve respecting reduced motion.
  static Curve animationCurve(BuildContext context, Curve normal) =>
      shouldAnimate(context) ? normal : Curves.linear;

  /// Trigger haptic feedback only on devices that support it.
  static void lightImpact() => HapticFeedback.lightImpact();
  static void selectionClick() => HapticFeedback.selectionClick();
  static void mediumImpact() => HapticFeedback.mediumImpact();

  /// Semantic label helper for accessibility.
  static String? semanticLabel(String? label) => label;

  /// Encode a JSON map safely (reusable helper).
  static String encodeJson(Map<String, dynamic> map) =>
      const JsonEncoder().convert(map);

  /// Decode a JSON string to a map safely.
  static Map<String, dynamic> decodeJson(String json) =>
      Map<String, dynamic>.from(const JsonDecoder().convert(json) as Map);

  /// Decode a JSON string to a list safely.
  static List<T> decodeList<T>(
    String json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final list = const JsonDecoder().convert(json) as List;
    return list
        .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
