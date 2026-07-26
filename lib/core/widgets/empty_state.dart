import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../utils/accessibility_utils.dart';
import '../utils/constants.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyState({
    super.key,
    this.icon = LucideIcons.receiptText,
    this.title = 'No data yet',
    this.message = '',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
            child: Icon(
              icon,
              size: 36,
              color: colorScheme.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTheme.displayStyle(
              size: 16,
              weight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: AppTheme.bodyStyle(
                  size: 13,
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate(target: AccessibilityUtils.shouldAnimate(context) ? null : 1.0)
        .fadeIn(duration: AppConstants.animNormal)
        .slideY(begin: 0.05);
  }
}

class ChartEmptyState extends StatelessWidget {
  final String message;

  const ChartEmptyState({
    super.key,
    this.message = 'No data to show',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.chartBar,
            size: 40,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTheme.bodyStyle(
              size: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
