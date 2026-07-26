import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/icon_helper.dart';
import '../../core/database/database.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/database_provider.dart';

/// Provider that allows the bar chart to set a target month for the calendar.
/// When set to a non-null DateTime (month), SpendCalendar will navigate to that month.
final calendarFocusTargetProvider = StateProvider<DateTime?>((ref) => null);

/// Interactive Spend Calendar with month grid, tap-to-drill-down,
/// long-press preview, swipe navigation, and category filtering.
class SpendCalendar extends ConsumerStatefulWidget {
  const SpendCalendar({super.key});

  @override
  ConsumerState<SpendCalendar> createState() => _SpendCalendarState();
}

class _SpendCalendarState extends ConsumerState<SpendCalendar> {
  late DateTime _currentMonth;
  DateTime? _previousMonth;
  String? _filterCategoryId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month, 1);
  }

  void _goToNextMonth() {
    _previousMonth = _currentMonth;
    setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1));
  }

  void _goToPrevMonth() {
    _previousMonth = _currentMonth;
    setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1));
  }

  void _showDaySheet(
    BuildContext context,
    DateTime date,
    List<Transaction> transactions,
    List<Category> categories,
    List<Account> accounts,
  ) {

    final total = transactions.fold<double>(0, (s, t) => s + t.amount);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(context).colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.3,
          expand: false,
          builder: (ctx, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
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

                  // Header: date + total
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
                          Text(
                            'Total spent',
                            style: AppTheme.bodyStyle(
                              size: 11, color: colorScheme.onSurfaceVariant,
                            ),
                          ),
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

                  // Transaction count
                  Text(
                    '${transactions.length} transaction${transactions.length != 1 ? 's' : ''}',
                    style: AppTheme.bodyStyle(
                      size: 12, color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Transaction list
                  Expanded(
                    child: transactions.isEmpty
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
                            itemCount: transactions.length,
                            separatorBuilder: (_, _) => Container(
                              height: 1,
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              color: colorScheme.outline.withValues(alpha: 0.06),
                            ),
                            itemBuilder: (ctx, index) {
                              final t = transactions[index];
                              final cat = categories.where((c) => c.id == t.categoryId).firstOrNull;
                              final acc = accounts.where((a) => a.id == t.accountId).firstOrNull;
                              final catColor = Color(cat?.color ?? 0xFF6B7280);
                              final timeStr = DateFormat('h:mm a').format(t.date);

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    // Category icon
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
                                          Text(
                                            t.note != null && t.note!.isNotEmpty ? t.note! : (cat?.name ?? 'Unknown'),
                                            style: AppTheme.bodyStyle(
                                              size: 14, weight: FontWeight.w500,
                                              color: colorScheme.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                cat?.name ?? 'Unknown',
                                                style: AppTheme.bodyStyle(
                                                  size: 11, color: colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text('•', style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4))),
                                              const SizedBox(width: 6),
                                              Text(
                                                timeStr,
                                                style: AppTheme.bodyStyle(
                                                  size: 11, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '-${Formatters.formatCurrency(t.amount)}',
                                          style: AppTheme.financialStyle(
                                            size: 14, weight: FontWeight.w600,
                                            color: AppColors.error,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(4),
                                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                                          ),
                                          child: Text(
                                            acc?.name ?? t.paymentMethod.toUpperCase(),
                                            style: AppTheme.bodyStyle(
                                              size: 9, weight: FontWeight.w600,
                                              color: colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
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

  void _showDayPreview(BuildContext context, DateTime date, double total, String? topCategory) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => GestureDetector(
        onTap: () => entry.remove(),
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              onTap: () {}, // prevent dismiss when tapping the popup itself
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? AppColors.elevatedDark : AppColors.cardLight,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
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
                        size: 16, weight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Total spent',
                      style: AppTheme.bodyStyle(
                        size: 11, color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      Formatters.formatCurrency(total),
                      style: AppTheme.financialStyle(
                        size: 28, weight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (topCategory != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: colorScheme.primary.withValues(alpha: 0.1),
                        ),
                        child: Text(
                          'Top: $topCategory',
                          style: AppTheme.bodyStyle(
                            size: 12, weight: FontWeight.w500,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
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
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final accounts = ref.watch(accountsProvider).valueOrNull ?? [];
    final allTransactions = ref.watch(transactionsProvider).valueOrNull ?? [];

    // Listen for calendar focus target from the bar chart (must be inside build)
    ref.listen<DateTime?>(calendarFocusTargetProvider, (_, next) {
      if (next != null && mounted) {
        final targetMonth = DateTime(next.year, next.month, 1);
        if (targetMonth != _currentMonth) {
          _previousMonth = _currentMonth;
          setState(() => _currentMonth = targetMonth);
        }
        // Reset the provider so re-tapping the same bar navigates again
        ref.read(calendarFocusTargetProvider.notifier).state = null;
      }
    });

    if (allTransactions.isEmpty) return const SizedBox.shrink();

    // ── STRICT EXPENSE FILTERING ──
    // Filter out income categories so income transactions are never tallied as spend!
    final expenseCatIds = categories.where((c) => c.type == 'expense').map((c) => c.id).toSet();

    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    final dailyTxns = <int, List<Transaction>>{};
    double monthTotal = 0;

    for (final t in allTransactions) {
      if (t.date.year == _currentMonth.year && t.date.month == _currentMonth.month) {
        if (t.amount > 0 && expenseCatIds.contains(t.categoryId)) {
          if (_filterCategoryId == null || t.categoryId == _filterCategoryId) {
            dailyTxns.putIfAbsent(t.date.day, () => []);
            dailyTxns[t.date.day]!.add(t);
            monthTotal += t.amount;
          }
        }
      }
    }

    // Calculate max daily spend & day totals
    double maxDaily = 0;
    final dayTotals = <int, double>{};

    for (int d = 1; d <= daysInMonth; d++) {
      final txns = dailyTxns[d] ?? [];
      final total = txns.fold<double>(0, (s, t) => s + t.amount);
      if (total > 0) {
        dayTotals[d] = total;
        if (total > maxDaily) maxDaily = total;
      }
    }

    // Calendar grid setup
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;
    // Convert weekday: in Dart, 1=Mon...7=Sun; we want 0=Sun...6=Sat
    final startOffset = firstWeekday % 7;
    final totalCells = startOffset + daysInMonth;
    final numWeeks = (totalCells / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row: icon + title + Today button ──
        Row(
          children: [
            Icon(LucideIcons.calendarDays, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              'Spend Calendar',
              style: AppTheme.displayStyle(
                size: 16, weight: FontWeight.w600, color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            if (_currentMonth.year != DateTime.now().year || _currentMonth.month != DateTime.now().month)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  _previousMonth = _currentMonth;
                  final now = DateTime.now();
                  setState(() => _currentMonth = DateTime(now.year, now.month, 1));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.calendarCheck, size: 14, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Today',
                        style: AppTheme.bodyStyle(
                          size: 12, weight: FontWeight.w600, color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Month card with grid ──
        GestureDetector(
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity != null) {
              if (details.primaryVelocity! < -100) {
                _goToNextMonth();
              } else if (details.primaryVelocity! > 100) {
                _goToPrevMonth();
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.cardRadius),
              color: isDark ? AppColors.cardDark : AppColors.cardLight,
              boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
            ),
            padding: AppConstants.cardPadding,
            child: Column(
              children: [
                // Month header with nav arrows, total, & no-spend stats
                GestureDetector(
                  onHorizontalDragEnd: (details) {
                    if (details.primaryVelocity != null) {
                      if (details.primaryVelocity! < -100) {
                        _goToNextMonth();
                      } else if (details.primaryVelocity! > 100) {
                        _goToPrevMonth();
                      }
                    }
                  },
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _goToPrevMonth,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          ),
                          child: Icon(LucideIcons.chevronLeft, size: 18, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            AnimatedSwitcher(
                              duration: 200.ms,
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                              child: Text(
                                Formatters.formatMonth(_currentMonth),
                                key: ValueKey('month_${_currentMonth.month}_${_currentMonth.year}'),
                                style: AppTheme.displayStyle(
                                  size: 16, weight: FontWeight.w600, color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: 200.ms,
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: child,
                              ),
                              child: Text(
                                'Spent ${Formatters.formatCurrency(monthTotal)}',
                                key: ValueKey('total_${_currentMonth.month}_${_currentMonth.year}'),
                                style: AppTheme.bodyStyle(
                                  size: 11, weight: FontWeight.w600, color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _goToNextMonth,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          ),
                          child: Icon(LucideIcons.chevronRight, size: 18, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // ── Animated body: filters + grid + legend ──
                AnimatedSwitcher(
                  duration: 350.ms,
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) {
                    final isForward = _previousMonth != null && _currentMonth.isAfter(_previousMonth!);
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(isForward ? 0.2 : -0.2, 0.0),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    key: ValueKey('body_${_currentMonth.year}_${_currentMonth.month}'),
                    children: [
                      const SizedBox(height: 14),

                      // ── Category & Tag filter chips ──
                      SizedBox(
                        height: 32,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _FilterChip(
                              label: 'All',
                              selected: _filterCategoryId == null,
                              color: colorScheme.primary,
                              onTap: () => setState(() {
                                _filterCategoryId = null;
                              }),
                            ),
                            const SizedBox(width: 6),
                            ...categories.where((c) => c.type == 'expense').map((cat) => Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: _FilterChip(
                                label: cat.name,
                                selected: _filterCategoryId == cat.id,
                                color: Color(cat.color),
                                onTap: () => setState(() {
                                  _filterCategoryId = _filterCategoryId == cat.id ? null : cat.id;
                                }),
                              ),
                            )),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Day-of-week header ──
                      Row(
                        children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) => Expanded(
                          child: Center(
                            child: Text(
                              d,
                              style: AppTheme.bodyStyle(
                                size: 11,
                                weight: FontWeight.w700,
                                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 6),

                      // ── Calendar grid ──
                      ...List.generate(numWeeks, (weekIdx) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: List.generate(7, (dayOfWeek) {
                              final dayNum = weekIdx * 7 + dayOfWeek - startOffset + 1;
                              final isValid = dayNum >= 1 && dayNum <= daysInMonth;

                              if (!isValid) {
                                return Expanded(child: Container(margin: const EdgeInsets.all(2), height: 46));
                              }

                              final dayTotal = dayTotals[dayNum] ?? 0.0;
                              final intensity = maxDaily > 0 ? (dayTotal / maxDaily) : 0.0;
                              final hasSpend = dayTotal > 0;
                              final isToday = dayNum == DateTime.now().day &&
                                  _currentMonth.year == DateTime.now().year &&
                                  _currentMonth.month == DateTime.now().month;

                              // ── Vibrant Color Palette ──
                              Color cellBgColor;
                              Color cellTextColor;
                              Border? cellBorder;

                              if (!hasSpend) {
                                cellBgColor = isDark
                                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
                                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);
                                cellTextColor = isToday
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
                                cellBorder = isToday
                                    ? Border.all(color: colorScheme.primary, width: 2.5)
                                    : Border.all(color: colorScheme.outline.withValues(alpha: 0.08));
                              } else if (intensity < 0.3) {
                                // Light Spend - Emerald Accent
                                cellBgColor = isDark
                                    ? const Color(0xFF10B981).withValues(alpha: 0.35)
                                    : const Color(0xFF10B981).withValues(alpha: 0.25);
                                cellTextColor = isDark ? Colors.white : const Color(0xFF047857);
                                cellBorder = Border.all(
                                  color: isToday ? colorScheme.primary : const Color(0xFF10B981).withValues(alpha: 0.5),
                                  width: isToday ? 2.5 : 1,
                                );
                              } else if (intensity < 0.65) {
                                // Medium Spend - Amber Accent
                                cellBgColor = isDark
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.50)
                                    : const Color(0xFFF59E0B).withValues(alpha: 0.35);
                                cellTextColor = isDark ? Colors.white : const Color(0xFFB45309);
                                cellBorder = Border.all(
                                  color: isToday ? colorScheme.primary : const Color(0xFFF59E0B).withValues(alpha: 0.6),
                                  width: isToday ? 2.5 : 1,
                                );
                              } else {
                                // Heavy Spend - Vibrant Crimson Accent
                                cellBgColor = isDark
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.75)
                                    : const Color(0xFFEF4444).withValues(alpha: 0.65);
                                cellTextColor = Colors.white;
                                cellBorder = Border.all(
                                  color: isToday ? colorScheme.primary : const Color(0xFFEF4444).withValues(alpha: 0.8),
                                  width: isToday ? 2.5 : 1,
                                );
                              }

                              final dayTransactions = dailyTxns[dayNum] ?? [];

                              return Expanded(
                                child: GestureDetector(
                                  onTap: isValid && hasSpend
                                      ? () => _showDaySheet(context,
                                          DateTime(_currentMonth.year, _currentMonth.month, dayNum),
                                          dayTransactions, categories, accounts)
                                      : null,
                                  onLongPress: isValid && hasSpend
                                      ? () {
                                          final topCatId = _getTopCategory(dayTransactions);
                                          final topCat = categories.where((c) => c.id == topCatId).firstOrNull;
                                          _showDayPreview(context,
                                              DateTime(_currentMonth.year, _currentMonth.month, dayNum),
                                              dayTotal, topCat?.name);
                                        }
                                      : null,
                                  child: AnimatedContainer(
                                    duration: 100.ms,
                                    margin: const EdgeInsets.all(2),
                                    height: 46,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      color: cellBgColor,
                                      border: cellBorder,
                                      boxShadow: isToday
                                          ? [
                                              BoxShadow(
                                                color: colorScheme.primary.withValues(alpha: 0.3),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                              )
                                            ]
                                          : null,
                                    ),
                                    child: Stack(
                                      children: [
                                        // ── Cell content ──
                                        Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                '$dayNum',
                                                style: AppTheme.bodyStyle(
                                                  size: 11,
                                                  weight: isToday ? FontWeight.w800 : FontWeight.w600,
                                                  color: cellTextColor,
                                                ),
                                              ),
                                              const SizedBox(height: 1),
                                              if (hasSpend)
                                                Text(
                                                  _formatCompactAmount(dayTotal),
                                                  style: TextStyle(
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: cellTextColor.withValues(alpha: 0.9),
                                                    fontFeatures: const [FontFeature.tabularFigures()],
                                                  ),
                                                )
                                              else
                                                Text(
                                                  '🍃',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),

                                        // ── TODAY Badge Pill ──
                                        if (isToday)
                                          Positioned(
                                            top: 2,
                                            right: 2,
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        );
                      }),

                      const SizedBox(height: 12),

                      // ── Legend ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendItem(color: const Color(0xFF10B981), label: 'Light'),
                          const SizedBox(width: 14),
                          _LegendItem(color: const Color(0xFFF59E0B), label: 'Medium'),
                          const SizedBox(width: 14),
                          _LegendItem(color: const Color(0xFFEF4444), label: 'Heavy'),
                          const SizedBox(width: 14),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: colorScheme.primary, width: 2),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Today',
                                style: AppTheme.bodyStyle(
                                  size: 10,
                                  weight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatCompactAmount(double val) {
    if (val >= 100000) return '₹${(val / 100000).toStringAsFixed(1)}L';
    if (val >= 1000) return '₹${(val / 1000).toStringAsFixed(val % 1000 == 0 ? 0 : 1)}k';
    return '₹${val.toInt()}';
  }

  String? _getTopCategory(List<Transaction> txns) {
    if (txns.isEmpty) return null;
    final counts = <String, double>{};
    for (final t in txns) {
      counts[t.categoryId] = (counts[t.categoryId] ?? 0) + t.amount;
    }
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}

/// Small filter chip for category selection.
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
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
            size: 12,
            weight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? color : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTheme.bodyStyle(
            size: 10, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
