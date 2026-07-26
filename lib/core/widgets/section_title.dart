import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final double size;
  final FontWeight weight;
  final double letterSpacing;

  const SectionTitle(
    this.title, {
    super.key,
    this.size = 12,
    this.weight = FontWeight.w600,
    this.letterSpacing = 0.5,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      title,
      style: AppTheme.bodyStyle(
        size: size,
        weight: weight,
        color: colorScheme.onSurfaceVariant,
        letterSpacing: letterSpacing,
      ),
    );
  }
}
