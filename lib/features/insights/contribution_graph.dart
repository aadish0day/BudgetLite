import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_helper.dart';
import 'package:intl/intl.dart';
import '../../core/database/database.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/database_provider.dart';

/// GitHub-style contribution graph showing daily spending intensity
/// across a full calendar year.
class ContributionGraph extends ConsumerStatefulWidget {
  const ContributionGraph({super.key});

  @override
  ConsumerState<ContributionGraph> createState() => _ContributionGraphState();
}

class _ContributionGraphState extends ConsumerState<ContributionGraph> {
  OverlayEntry? _tooltipEntry;
  late int _selectedYear;
  String? _filterCategoryId;

  // Computed stats
  int _currentStreak = 0;
  int _longestStreak = 0;
  double _totalYearly = 0;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  @override
  void dispose() {
    _tooltipEntry?.remove();
    super.dispose();
  }

  void _goToPrevYear() {
    setState(() => _selectedYear--);
  }

  void _goToNextYear() {
    setState(() => _selectedYear++);
  }

  /// Build the per-day spend map for the selected year.
  Map<DateTime, double> _buildDailySpend(List<Transaction> allTransactions) {
    final daily = <DateTime, double>{};
    // Exclude transfers — balance-neutral, consistent with the calendar and
    // every other spending view.
    for (final t in allTransactions.where((t) => t.amount > 0 && t.categoryId != 'transfer')) {
      if (t.date.year != _selectedYear) continue;
      if (_filterCategoryId != null && t.categoryId != _filterCategoryId) continue;

      final dayKey = DateTime(t.date.year, t.date.month, t.date.day);
      daily[dayKey] = (daily[dayKey] ?? 0.0) + t.amount;
    }
    return daily;
  }

  /// Calculate streak stats and yearly total.
  void _computeStats(Map<DateTime, double> daily, int daysInYear) {
    double total = 0;
    int current = 0;
    int longest = 0;

    final firstDay = DateTime(_selectedYear, 1, 1);
    final today = DateTime.now();
    final isCurrentYear = _selectedYear == today.year;

    // Walk forward through the year. For current year, stop at today
    // to avoid counting future days as no-spend streak.
    final loopDays = isCurrentYear
        ? today.difference(firstDay).inDays + 1
        : daysInYear;

    for (int i = 0; i < loopDays; i++) {
      final day = firstDay.add(Duration(days: i));
      final spent = daily[day] ?? 0.0;
      total += spent;

      if (spent == 0) {
        current++;
        if (current > longest) longest = current;
      } else {
        current = 0;
      }
    }

    _currentStreak = isCurrentYear ? current : 0;
    _longestStreak = longest;
    _totalYearly = total;
  }

  /// Compute intensity level using quartile-based thresholds from the user's
  /// own historical daily spending data (relative, not fixed amounts).
  /// Levels: 0=none, 1=low (≤25th percentile), 2=medium (25th-50th),
  /// 3=high (50th-75th), 4=max (>75th percentile or outlier).
  int _getIntensityLevel(double dailySpend, double avgDaily,
      [List<double>? allDailyAmounts]) {
    if (dailySpend == 0) return 0;
    if (allDailyAmounts == null || allDailyAmounts.length < 4) {
      // Fallback: use avgDaily when we don't have enough data for quartiles
      if (avgDaily == 0) return 4;
      final ratio = dailySpend / avgDaily;
      if (ratio <= 0.25) return 1;
      if (ratio <= 0.5) return 2;
      if (ratio <= 1.0) return 3;
      return 4;
    }

    // Sort non-zero amounts and compute quartile thresholds
    final sorted = List<double>.from(allDailyAmounts.where((v) => v > 0))..sort();
    if (sorted.isEmpty) return 0;

    final n = sorted.length;
    final q1 = sorted[(n * 0.25).round().clamp(0, n - 1)];
    final q2 = sorted[(n * 0.50).round().clamp(0, n - 1)];
    final q3 = sorted[(n * 0.75).round().clamp(0, n - 1)];

    if (dailySpend <= q1) return 1;
    if (dailySpend <= q2) return 2;
    if (dailySpend <= q3) return 3;
    return 4;
  }

  Color _getCellColor(int level, bool isDark, [Color? accentColor]) {
    final base = accentColor ?? AppColors.primary;
    switch (level) {
      case 0:
        return isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.04);
      case 1:
        return base.withValues(alpha: 0.2);
      case 2:
        return base.withValues(alpha: 0.45);
      case 3:
        return base.withValues(alpha: 0.7);
      case 4:
        return base;
      default:
        return Colors.transparent;
    }
  }

  void _showDaySheet(BuildContext context, DateTime date, double spent,
      List<Transaction> allTransactions, List<Category> categories) {
    // Get transactions for this specific day
    final dayTxns = allTransactions.where((t) =>
        t.amount > 0 &&
        t.date.year == date.year &&
        t.date.month == date.month &&
        t.date.day == date.day &&
        (_filterCategoryId == null || t.categoryId == _filterCategoryId)
    ).toList();

    final total = dayTxns.fold<double>(0, (s, t) => s + t.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          expand: false,
          builder: (ctx, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          Formatters.formatDate(date),
                          style: AppTheme.displayStyle(
                            size: 18, weight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Spent',
                              style: AppTheme.bodyStyle(
                                  size: 11, color: colorScheme.onSurfaceVariant)),
                          Text(
                            Formatters.formatCurrency(total),
                            style: AppTheme.financialStyle(
                              size: 20, weight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(height: 1, color: colorScheme.outline.withValues(alpha: 0.15)),
                  const SizedBox(height: 12),
                  Text(
                    '${dayTxns.length} transaction${dayTxns.length != 1 ? 's' : ''}',
                    style: AppTheme.bodyStyle(
                      size: 12, color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: dayTxns.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.receiptText, size: 40,
                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                                const SizedBox(height: 12),
                                Text('No transactions on this day',
                                    style: AppTheme.bodyStyle(
                                        size: 14, color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            itemCount: dayTxns.length,
                            separatorBuilder: (_, _) => Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              color: colorScheme.outline.withValues(alpha: 0.06),
                            ),
                            itemBuilder: (ctx, index) {
                              final t = dayTxns[index];
                              final cat = categories.where((c) => c.id == t.categoryId).firstOrNull;
                              final catColor = Color(cat?.color ?? 0xFF6B7280);

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40, height: 40,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        color: catColor.withValues(alpha: 0.12),
                                      ),
                                      child: Icon(
                                        getCategoryIcon(cat?.icon ?? ''),
                                        size: 18, color: catColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(cat?.name ?? 'Unknown',
                                              style: AppTheme.bodyStyle(
                                                  size: 14, weight: FontWeight.w500,
                                                  color: colorScheme.onSurface)),
                                          if (t.note != null && t.note!.isNotEmpty)
                                            Text(t.note!,
                                                style: AppTheme.bodyStyle(
                                                    size: 12, color: colorScheme.onSurfaceVariant),
                                                maxLines: 1, overflow: TextOverflow.ellipsis),
                                        ],
                                      ),
                                    ),
                                    Text('-${Formatters.formatCurrency(t.amount)}',
                                        style: AppTheme.financialStyle(
                                            size: 14, weight: FontWeight.w600,
                                            color: AppColors.error)),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTooltip(BuildContext context, DateTime date, double spent, int level) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final overlay = Overlay.of(context);

    // Only one tooltip at a time
    _tooltipEntry?.remove();
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        onTap: () {
          _tooltipEntry = null;
          entry.remove();
        },
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 200,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isDark ? AppColors.elevatedDark : AppColors.cardLight,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      Formatters.formatDate(date),
                      style: AppTheme.displayStyle(
                        size: 15, weight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      spent == 0 ? 'No spend' : 'Spent ${Formatters.formatCurrency(spent)}',
                      style: AppTheme.bodyStyle(
                        size: 13, color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (spent > 0) ...[
                      const SizedBox(height: 6),
                      // Mini intensity indicator
                      Container(
                        width: 12, height: 12,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: _getCellColor(level, isDark),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Tap anywhere to close',
                      style: AppTheme.bodyStyle(
                        size: 10, color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ).animate().scale(
                begin: const Offset(0.85, 0.85),
                end: const Offset(1, 1),
                duration: 200.ms,
                curve: Curves.easeOutBack,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    _tooltipEntry = entry;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final activeCategory = categories.where((c) => c.id == _filterCategoryId).firstOrNull;
    final categoryColor = activeCategory != null ? Color(activeCategory.color) : null;
    final allTransactions = ref.watch(transactionsProvider).valueOrNull ?? [];

    if (allTransactions.isEmpty) return const SizedBox.shrink();

    // Build daily spend map for the year
    final daily = _buildDailySpend(allTransactions);

    // Year setup
    final firstDay = DateTime(_selectedYear, 1, 1);
    final daysInYear = _selectedYear % 4 == 0 &&
        (_selectedYear % 100 != 0 || _selectedYear % 400 == 0) ? 366 : 365;

    _computeStats(daily, daysInYear);

    // Calculate average daily spend (only on days with spend)
    final daysWithSpend = daily.values.where((v) => v > 0).length;
    final avgDaily = daysWithSpend > 0 ? _totalYearly / daysWithSpend : 0.0;

    // All daily amounts for quartile-based intensity thresholds
    final allDailyAmounts = daily.values.toList();

    // Arrange days into weekly columns
    // GitHub style: columns = weeks, rows = days (Sun=0, Mon=1, ..., Sat=6)
    // First column starts on Jan 1, which may not be Sunday
    final firstWeekday = firstDay.weekday % 7; // 0=Sun
    final numWeeks = ((daysInYear + firstWeekday) / 7.0).ceil();

    // Pre-compute cell data
    final cellData = <_CellInfo>[];
    for (int w = 0; w < numWeeks; w++) {
      for (int d = 0; d < 7; d++) {
        final dayOfYear = w * 7 + d - firstWeekday;
        if (dayOfYear < 0 || dayOfYear >= daysInYear) {
          cellData.add(_CellInfo.empty);
        } else {
          final date = firstDay.add(Duration(days: dayOfYear));
          final spent = daily[date] ?? 0.0;
          final level = _getIntensityLevel(spent, avgDaily, allDailyAmounts);
          cellData.add(_CellInfo(date: date, spent: spent, level: level));
        }
      }
    }

    // Month labels for the top
    final monthLabels = <_MonthLabelInfo>[];
    for (int m = 1; m <= 12; m++) {
      final monthStart = DateTime(_selectedYear, m, 1);
      final dayOfYear = monthStart.difference(firstDay).inDays;
      // Column index = (dayOfYear + firstWeekday) ~/ 7
      final col = (dayOfYear + firstWeekday) ~/ 7;
      if (col < numWeeks) {
        monthLabels.add(_MonthLabelInfo(
          label: DateFormat('MMM').format(monthStart),
          col: col,
        ));
      }
    }

    // Day labels on the left: only Mon, Wed, Fri
    const dayLabels = ['', 'Mon', '', 'Wed', '', 'Fri', ''];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Row(
          children: [
            Icon(LucideIcons.gitCommitHorizontal, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'Spending Activity',
              style: AppTheme.displayStyle(
                size: 16, weight: FontWeight.w600, color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Stats strip ──
        Row(
          children: [
            _StatBadge(
              icon: LucideIcons.flame,
              value: '$_currentStreak day${_currentStreak != 1 ? 's' : ''}',
              label: 'Current streak',
              color: AppColors.warning,
            ),
            const SizedBox(width: 10),
            _StatBadge(
              icon: LucideIcons.trophy,
              value: '$_longestStreak day${_longestStreak != 1 ? 's' : ''}',
              label: 'Longest streak',
              color: colorScheme.primary,
            ),
            const SizedBox(width: 10),
            _StatBadge(
              icon: LucideIcons.indianRupee,
              value: Formatters.formatCurrency(_totalYearly),
              label: 'Year total',
              color: AppColors.success,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Card ──
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.cardRadius),
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 6, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Year selector
              Row(
                children: [
                  GestureDetector(
                    onTap: _goToPrevYear,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      ),
                      child: Icon(LucideIcons.chevronLeft, size: 14, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$_selectedYear',
                    style: AppTheme.displayStyle(
                      size: 14, weight: FontWeight.w600, color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _goToNextYear,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      ),
                      child: Icon(LucideIcons.chevronRight, size: 14, color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                  const Spacer(),
                  // Info text
                  Text(
                    daysWithSpend > 0
                        ? 'Avg ₹${avgDaily.toStringAsFixed(0)}/day'
                        : 'No spend data',
                    style: AppTheme.bodyStyle(
                      size: 10, color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Grid with month labels + day labels ──
              SizedBox(
                height: 150,
                child: Row(
                  children: [
                    // Day labels column (fixed width)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: dayLabels.map((label) {
                        if (label.isEmpty) {
                          return const SizedBox(width: 28, height: 14);
                        }
                        return Container(
                          width: 28,
                          height: 14,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            label,
                            style: AppTheme.bodyStyle(
                              size: 8, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(width: 4),
                    // Scrollable grid area
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Month labels row
                            SizedBox(
                              height: 14,
                              child: Row(
                                children: List.generate(numWeeks, (w) {
                                  final monthLabel = monthLabels.where((m) => m.col == w).firstOrNull;
                                  return SizedBox(
                                    width: 14,
                                    child: monthLabel != null
                                        ? Text(
                                            monthLabel.label,
                                            style: AppTheme.bodyStyle(
                                              size: 8, weight: FontWeight.w600,
                                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                            ),
                                          )
                                        : null,
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Cells grid (7 rows × numWeeks columns)
                            ...List.generate(7, (row) {
                              return Row(
                                children: List.generate(numWeeks, (col) {
                                  final idx = col * 7 + row;
                                  final info = idx < cellData.length ? cellData[idx] : _CellInfo.empty;
                                  final cellColor = info.level >= 0
                                      ? _getCellColor(info.level, isDark, categoryColor)
                                      : Colors.transparent;

                                  Color? borderColor;
                                  // Check if today
                                  if (info.date != null &&
                                      info.date!.year == DateTime.now().year &&
                                      info.date!.month == DateTime.now().month &&
                                      info.date!.day == DateTime.now().day) {
                                    borderColor = colorScheme.primary;
                                  }

                                  return GestureDetector(
                                    onTap: info.date != null && info.spent! > 0
                                        ? () => _showDaySheet(
                                            context, info.date!, info.spent!,
                                            allTransactions, categories)
                                        : null,
                                    onLongPress: info.date != null
                                        ? () => _showTooltip(
                                            context, info.date!, info.spent ?? 0.0, info.level)
                                        : null,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      margin: const EdgeInsets.all(1.5),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        color: cellColor,
                                        border: borderColor != null
                                            ? Border.all(color: borderColor, width: 1.5)
                                            : null,
                                      ),
                                    ),
                                  );
                                }),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // ── Category filter chips ──
              SizedBox(
                height: 28,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'All',
                      selected: _filterCategoryId == null,
                      color: colorScheme.primary,
                      onTap: () => setState(() => _filterCategoryId = null),
                    ),
                    const SizedBox(width: 6),
                    ...categories.where((c) => c.type == 'expense').map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _FilterChip(
                        label: cat.name,
                        selected: _filterCategoryId == cat.id,
                        color: Color(cat.color),
                        onTap: () => setState(() => _filterCategoryId = cat.id),
                      ),
                    )),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Legend ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Less',
                    style: AppTheme.bodyStyle(
                      size: 9, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...List.generate(5, (i) => Container(
                    width: 12, height: 12,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: _getCellColor(i, isDark, categoryColor),
                    ),
                  )),
                  const SizedBox(width: 6),
                  Text(
                    'More',
                    style: AppTheme.bodyStyle(
                      size: 9, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms);
  }
}

class _CellInfo {
  final DateTime? date;
  final double? spent;
  final int level; // -1 for empty cell

  _CellInfo({this.date, this.spent, this.level = 0});

  static final empty = _CellInfo(level: -1);
}

class _MonthLabelInfo {
  final String label;
  final int col;

  const _MonthLabelInfo({required this.label, required this.col});
}

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    value,
                    style: AppTheme.bodyStyle(
                      size: 11, weight: FontWeight.w600,
                      color: colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              label,
              style: AppTheme.bodyStyle(
                size: 9, color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: selected
              ? color.withValues(alpha: 0.15)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: selected
              ? Border.all(color: color.withValues(alpha: 0.3))
              : null,
        ),
        child: Text(
          label,
          style: AppTheme.bodyStyle(
            size: 11,
            weight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? color : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
