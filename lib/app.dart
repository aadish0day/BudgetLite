import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/colors.dart';
import 'core/utils/sms_parser.dart';
import 'core/utils/formatters.dart';
import 'core/utils/accessibility_utils.dart';
import 'features/home/home_screen.dart';
import 'features/transactions/transactions_screen.dart';
import 'features/transactions/add_transaction_sheet.dart';
import 'features/budget/budget_screen.dart';
import 'features/goals/goals_screen.dart';
import 'features/insights/insights_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'core/utils/notification_service.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/navigation_provider.dart';
import 'core/services/sms_listener_service.dart';
import 'main.dart' show quickActionCallbackProvider, setupQuickActions;

class BudgetLiteApp extends ConsumerWidget {
  const BudgetLiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeOption = ref.watch(themeModeProvider).valueOrNull ?? ThemeModeOption.light;
    final accentColorVal = ref.watch(accentColorProvider).valueOrNull;

    final themeMode = switch (themeOption) {
      ThemeModeOption.light => ThemeMode.light,
      ThemeModeOption.dark => ThemeMode.dark,
      ThemeModeOption.system => ThemeMode.system,
    };

    ThemeData lightTheme = AppTheme.light;
    ThemeData darkTheme = AppTheme.dark;

    if (accentColorVal != null) {
      final accentColor = Color(accentColorVal);
      lightTheme = lightTheme.copyWith(
        colorScheme: lightTheme.colorScheme.copyWith(
          primary: accentColor,
        ),
      );
      darkTheme = darkTheme.copyWith(
        colorScheme: darkTheme.colorScheme.copyWith(
          primary: accentColor,
        ),
      );
    }

    return MaterialApp(
      title: 'BudgetLite',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: themeMode,
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends ConsumerStatefulWidget {
  const _AppEntry();

  @override
  ConsumerState<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<_AppEntry> with WidgetsBindingObserver {
  bool _showOnboarding = true;
  bool _isAuthenticated = false;
  bool _biometricEnabled = false;
  bool _checkingAuth = true;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOnboarding();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final biometric = ref.read(biometricLockEnabledProvider).valueOrNull ?? false;
      if (_backgroundedAt != null && biometric && _isAuthenticated) {
        final durationMinutes = ref.read(autoLockDurationProvider).valueOrNull ?? 1;
        final elapsedSeconds = DateTime.now().difference(_backgroundedAt!).inSeconds;
        if (elapsedSeconds >= durationMinutes * 60) {
          setState(() {
            _isAuthenticated = false;
            _biometricEnabled = true;
          });
          _authenticate();
        }
      }
      _backgroundedAt = null;
    }
  }

  Future<void> _checkOnboarding() async {
    final settings = ref.read(settingsNotifierProvider.notifier);
    final seen = await settings.getSetting('onboarding_seen');
    final biometric = await settings.getSetting('biometric_lock') == 'true';
    if (mounted) {
      setState(() {
        _showOnboarding = seen != 'true';
        _biometricEnabled = biometric;
        _isAuthenticated = !biometric;
        _checkingAuth = false;
      });
      if (seen == 'true' && biometric) {
        _authenticate();
      }
    }
  }

  bool _isAuthenticating = false;

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    final localAuth = LocalAuthentication();
    try {
      final isAvailable = await localAuth.canCheckBiometrics;
      final isSupported = await localAuth.isDeviceSupported();
      if (isAvailable || isSupported) {
        final didAuthenticate = await localAuth.authenticate(
          localizedReason: 'Authenticate to access BudgetLite',
        );
        if (mounted) {
          setState(() {
            _isAuthenticated = didAuthenticate;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
          });
        }
      }
    } on PlatformException catch (_) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
        });
      }
    } finally {
      _isAuthenticating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAuth) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_showOnboarding) {
      return OnboardingScreen(
        onComplete: () async {
          await ref
              .read(settingsNotifierProvider.notifier)
              .setSetting('onboarding_seen', 'true');
          if (mounted) {
            setState(() {
              _showOnboarding = false;
              _isAuthenticated = true;
            });
          }
        },
      );
    }

    if (_biometricEnabled && !_isAuthenticated) {
      return _LockScreen(onRetry: _authenticate);
    }

    return const _MainShell();
  }
}

class _MainShell extends ConsumerStatefulWidget {
  const _MainShell();

  @override
  ConsumerState<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<_MainShell> {
  bool _isSmsDialogShowing = false;

  @override
  void initState() {
    super.initState();
    NotificationService.instance.initialize(
      onNotificationTap: (payload) {
        if (payload != null && payload.startsWith('budget:')) {
          final isBudgetEnabled = ref.read(budgetModuleEnabledProvider).valueOrNull ?? true;
          if (isBudgetEnabled) {
            final catId = payload.substring('budget:'.length);
            ref.read(currentTabProvider.notifier).state = 2;
            ref.read(budgetHighlightProvider.notifier).state = catId;
          }
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(transactionNotifierProvider.notifier).postDueRecurringTransactions();
      setupQuickActions(ref);
      ref.read(quickActionCallbackProvider.notifier).state = (tabIndex) {
        ref.read(currentTabProvider.notifier).state = tabIndex;
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    final rawTab = ref.watch(currentTabProvider);
    final isBudgetEnabled = ref.watch(budgetModuleEnabledProvider).valueOrNull ?? true;
    final shouldAnimate = AccessibilityUtils.shouldAnimate(context);

    final navLabels = [
      'Home',
      'Transactions',
      if (isBudgetEnabled) 'Budget',
      'Goals',
      'Insights',
    ];

    final screens = [
      const HomeScreen(),
      const TransactionsScreen(),
      if (isBudgetEnabled) const BudgetScreen(),
      const GoalsScreen(),
      const InsightsScreen(),
    ];

    final navIcons = [
      (LucideIcons.house, LucideIcons.house),
      (LucideIcons.receipt, LucideIcons.receipt),
      if (isBudgetEnabled) (LucideIcons.wallet, LucideIcons.wallet),
      (LucideIcons.flag, LucideIcons.flag),
      (LucideIcons.chartBar, LucideIcons.chartBar),
    ];

    final currentTab = rawTab >= screens.length ? 0 : rawTab;

    ref.listen<ParsedSmsTxn?>(pendingSmsTransactionProvider, (_, next) {
      if (next != null && !_isSmsDialogShowing) {
        _showSmsConfirmationDialog(context, next);
      }
    });

    ref.listen(transactionsProvider, (prev, next) {
      next.whenData((txns) {
        NotificationService.instance.rescheduleAll(txns);
      });
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(LucideIcons.logOut, size: 20, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Exit BudgetLite?',
                  style: AppTheme.displayStyle(size: 18, weight: FontWeight.w600),
                ),
              ],
            ),
            content: Text(
              'Are you sure you want to exit the app?',
              style: AppTheme.bodyStyle(size: 14, color: colorScheme.onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: AppTheme.bodyStyle(color: colorScheme.onSurfaceVariant)),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Exit', style: AppTheme.bodyStyle(weight: FontWeight.w600)),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: shouldAnimate
            ? AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return ScaleTransition(
                    scale: Tween<double>(begin: 0.97, end: 1.0).animate(
                      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                    ),
                    child: FadeTransition(
                      opacity: Tween<double>(begin: 0.3, end: 1.0).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: screens[currentTab],
              )
            : screens[currentTab],
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isDark
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.9)
                    : colorScheme.surface.withValues(alpha: 0.95),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.12),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(screens.length, (i) {
                  final isSelected = currentTab == i;
                  final icon = navIcons[i].$1;
                  final label = navLabels[i];

                  return Flexible(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(currentTabProvider.notifier).state = i;
                      },
                      behavior: HitTestBehavior.opaque,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        padding: EdgeInsets.symmetric(
                          horizontal: isSelected ? 10 : 6,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: isSelected
                              ? colorScheme.primary.withValues(alpha: 0.14)
                              : Colors.transparent,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: isSelected ? 1.15 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                icon,
                                size: 20,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 3),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: AppTheme.bodyStyle(
                                size: 10,
                                weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        floatingActionButton: currentTab <= 1
            ? FloatingActionButton.extended(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showAddOptions(context);
                },
                icon: const Icon(LucideIcons.plus, size: 20),
                label: const Text('Add'),
              )
            : null,
      ),
    );
  }

  BottomNavigationBarItem _bottomNavItem(
      IconData outlined, IconData filled, String label, int currentTab, int index) {
    final isSelected = currentTab == index;
    return BottomNavigationBarItem(
      icon: Icon(isSelected ? filled : outlined),
      activeIcon: Icon(filled),
      label: label,
    );
  }

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              const SizedBox(height: 20),
              Text('Quick Entry', style: AppTheme.displayStyle(size: 18, weight: FontWeight.w600, color: colorScheme.onSurface)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionButton(
                      icon: LucideIcons.minusCircle,
                      label: 'Log Expense',
                      color: colorScheme.primary,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddTransaction(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionButton(
                      icon: LucideIcons.plusCircle,
                      label: 'Add Pocket Money',
                      color: AppColors.success,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddIncome(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showAddTransaction(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddTransactionSheet(),
    );
  }

  void _showAddIncome(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddTransactionSheet(initialType: 'income'),
    );
  }

  void _showSmsConfirmationDialog(BuildContext context, ParsedSmsTxn txn) {
    _isSmsDialogShowing = true;
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(LucideIcons.messageSquare, color: colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              'Bank SMS Detected',
              style: AppTheme.displayStyle(size: 18, weight: FontWeight.w600),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We found a new transaction details from your SMS message:',
              style: AppTheme.bodyStyle(size: 13, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline.withValues(alpha: 0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Amount', style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant)),
                      Text('Category', style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${txn.amount.toStringAsFixed(0)}',
                        style: AppTheme.financialStyle(size: 18, weight: FontWeight.w700, color: colorScheme.onSurface),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          txn.categoryId.toUpperCase(),
                          style: AppTheme.bodyStyle(size: 11, weight: FontWeight.w600, color: colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Note / Merchant', style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(txn.note, style: AppTheme.bodyStyle(size: 13, weight: FontWeight.w500, color: colorScheme.onSurface)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(pendingSmsTransactionProvider.notifier).state = null;
              Navigator.pop(ctx);
            },
            child: Text('Ignore', style: AppTheme.bodyStyle(color: colorScheme.onSurfaceVariant)),
          ),
          FilledButton(
            onPressed: () async {
              if (!ctx.mounted) return;
              final notifier = ref.read(transactionNotifierProvider.notifier);

              final dupCheck = await notifier.checkForDuplicates(
                amount: txn.amount,
                categoryId: txn.categoryId,
                date: txn.date,
                note: txn.note,
                isIncome: txn.isIncome,
              );

              if (!ctx.mounted) return;
              if (dupCheck.isNotEmpty) {
                final addAnyway = await showDialog<bool>(
                  context: ctx,
                  builder: (dialogCtx) => AlertDialog(
                    title: Row(
                      children: [
                        Icon(LucideIcons.alertTriangle, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Text('Possible Duplicate',
                          style: AppTheme.displayStyle(size: 18, weight: FontWeight.w600)),
                      ],
                    ),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('A similar transaction already exists:',
                          style: AppTheme.bodyStyle(size: 14, color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 12),
                        ...dupCheck.take(3).map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(LucideIcons.receiptText, size: 14, color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '₹${d.amount.abs().toStringAsFixed(0)} on ${Formatters.formatDateShort(d.date)}',
                                  style: AppTheme.bodyStyle(size: 12, color: colorScheme.onSurface),
                                ),
                              ),
                            ],
                          ),
                        )),
                        if (dupCheck.length > 3)
                          Text('...and ${dupCheck.length - 3} more',
                            style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant)),
                        const SizedBox(height: 12),
                        Text('Add it anyway?',
                          style: AppTheme.bodyStyle(size: 14, color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogCtx, false),
                        child: Text('Cancel', style: AppTheme.bodyStyle(color: colorScheme.onSurfaceVariant)),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogCtx, true),
                        child: const Text('Add Anyway'),
                      ),
                    ],
                  ),
                );
                if (addAnyway != true) return;
              }

              if (!ctx.mounted) return;
              await notifier.addTransaction(
                amount: txn.amount,
                categoryId: txn.categoryId,
                note: txn.note,
                date: txn.date,
                paymentMethod: 'UPI',
                isIncome: txn.isIncome,
              );
              ref.read(pendingSmsTransactionProvider.notifier).state = null;
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Transaction added successfully!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(txn.isIncome ? 'Add Income' : 'Add Expense', style: AppTheme.bodyStyle(weight: FontWeight.w600)),
          ),
        ],
      ),
    ).then((_) => _isSmsDialogShowing = false);
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTheme.bodyStyle(size: 13, weight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _LockScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withValues(alpha: 0.1),
                ),
                child: Icon(LucideIcons.lock, size: 40, color: colorScheme.primary),
              ),
              const SizedBox(height: 24),
              Text('BudgetLite Locked',
                style: AppTheme.displayStyle(size: 22, weight: FontWeight.w700, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'Please unlock with your biometric credentials to manage your budget.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyStyle(size: 14, color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.fingerprint),
                label: const Text('Tap to Unlock'),
                style: FilledButton.styleFrom(minimumSize: const Size(200, 50)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onRetry,
                child: Text('Use Passcode / Retry',
                  style: AppTheme.bodyStyle(size: 13, color: colorScheme.primary, weight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
