import 'package:flutter/material.dart';
import '../utils/accessibility_utils.dart';
import '../utils/constants.dart';

class LoadingSkeleton extends StatelessWidget {
  const LoadingSkeleton({super.key, this.heights = const [100, 280, 220]});
  final List<double> heights;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: AppConstants.screenPadding,
      children: [
        for (var i = 0; i < heights.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          Container(
            height: heights[i],
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(AppConstants.cardRadius),
            ),
          ).animateShimmer(
            context,
            delay: Duration(milliseconds: i * 180),
          ),
        ],
      ],
    );
  }
}

class TransactionSkeleton extends StatelessWidget {
  const TransactionSkeleton({super.key, this.itemCount = 4});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final mutedColor = colorScheme.surfaceContainerHighest.withValues(alpha: 0.4);

    return Column(
      children: List.generate(
        itemCount,
        (i) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: baseColor,
                ),
              ).animateShimmer(
                context,
                delay: Duration(milliseconds: i * 100),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100 + (i * 30).toDouble(),
                      height: 14,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ).animateShimmer(
                      context,
                      delay: Duration(milliseconds: 150 + i * 100),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 60,
                      height: 11,
                      decoration: BoxDecoration(
                        color: mutedColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ).animateShimmer(
                      context,
                      delay: Duration(milliseconds: 300 + i * 100),
                    ),
                  ],
                ),
              ),
              Container(
                width: 60,
                height: 16,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ).animateShimmer(
                context,
                delay: Duration(milliseconds: 100 + i * 100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
