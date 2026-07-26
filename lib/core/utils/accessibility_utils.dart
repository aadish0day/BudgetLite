import 'package:flutter/widgets.dart';

/// Accessibility utilities for motion and animation preferences.
abstract class AccessibilityUtils {
  /// Returns `true` if the user has NOT requested reduced motion.
  static bool shouldAnimate(BuildContext context) =>
      !MediaQuery.of(context).disableAnimations;
}
