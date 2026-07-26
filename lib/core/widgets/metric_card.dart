import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_theme.dart';
import '../theme/colors.dart';
import '../utils/constants.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;
  final ColorScheme colorScheme;
  final String? prefix;
  final bool isNegative;
  final String? subtitle;

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.colorScheme,
    this.prefix,
    this.isNegative = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.08),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            '${prefix ?? ''}$value',
            style: AppTheme.financialStyle(
              size: 20,
              weight: FontWeight.w700,
              color: isNegative ? AppColors.error : colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.bodyStyle(
              size: 12,
              color: isNegative ? AppColors.error : colorScheme.onSurfaceVariant,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(LucideIcons.alertTriangle, size: 10, color: AppColors.error),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    subtitle!,
                    style: AppTheme.bodyStyle(
                      size: 9,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
