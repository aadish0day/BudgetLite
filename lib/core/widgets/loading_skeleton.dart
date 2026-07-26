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

class TransactionSkeleton extends StatelessWidget {
  final int itemCount;

  const TransactionSkeleton({
    super.key,
    this.itemCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final shimmerColor = colorScheme.primary.withValues(alpha: 0.04);
    return Column(
      children: List.generate(itemCount, (i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: colorScheme.surfaceContainerHighest,
              ),
            ).animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1200.ms, delay: (i * 100).ms, color: shimmerColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100 + (i * 30).toDouble(),
                    height: 14,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1200.ms, delay: (150 + i * 100).ms, color: shimmerColor),
                  const SizedBox(height: 6),
                  Container(
                    width: 60, height: 11,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1200.ms, delay: (300 + i * 100).ms, color: shimmerColor),
                ],
              ),
            ),
            Container(
              width: 60, height: 16,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
              ),
            ).animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1200.ms, delay: (100 + i * 100).ms, color: shimmerColor),
          ],
        ),
      )),
    );
  }
}
