import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/constants.dart';

class LoadingSkeleton extends StatelessWidget {
  final List<double> heights;

  const LoadingSkeleton({
    super.key,
    this.heights = const [100, 280, 220],
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: AppConstants.screenPadding,
      children: [
        for (var i = 0; i < heights.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          Container(
            height: heights[i],
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppConstants.cardRadius),
            ),
          ).animate(onPlay: (c) => c.repeat())
            .shimmer(
              duration: 1200.ms,
              delay: (i * 200).ms,
              color: colorScheme.primary.withValues(alpha: 0.08),
            ),
        ],
      ],
    );
  }
}
