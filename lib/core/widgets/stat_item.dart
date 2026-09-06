import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../utils/accessibility_utils.dart';
import '../utils/constants.dart';

class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.valueColor,
    this.delayMs = 0,
  });
  final String label;
  final String value;
  final Color color;
  final Color valueColor;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child:
          Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTheme.bodyStyle(
                      size: 11,
                      weight: FontWeight.w500,
                      color: color.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: AppTheme.financialStyle(
                      weight: FontWeight.w700,
                      color: valueColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              )
              .animate(
                target: AccessibilityUtils.shouldAnimate(context) ? null : 1.0,
              )
              .fadeIn(duration: AppConstants.animNormal, delay: delayMs.ms)
              .slideX(begin: 0.04, curve: Curves.easeOutCubic),
    );
  }
}
