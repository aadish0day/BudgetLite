import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/colors.dart';
import 'core/utils/sms_parser.dart';
import 'core/utils/formatters.dart';
import 'features/home/home_screen.dart';
import 'features/transactions/transactions_screen.dart';
import 'features/transactions/add_transaction_sheet.dart';
import 'features/transactions/transfer_sheet.dart';
import 'features/transactions/split_transaction_sheet.dart';
import 'features/budget/budget_screen.dart';
import 'features/goals/goals_screen.dart';
import 'features/insights/insights_screen.dart';
import 'features/debt/debt_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'core/utils/notification_service.dart';
import 'providers/settings_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/navigation_provider.dart';
import 'main.dart' show registerTabNavigation;

class BudgetLiteApp extends ConsumerWidget {
  const BudgetLiteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final darkMode = ref.watch(darkModeProvider).valueOrNull ?? false;

    return MaterialApp(
      title: 'BudgetLite',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends ConsumerStatefulWidget {
  const _AppEntry();

  @override
  ConsumerState<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<_AppEntry> {
  bool _showOnboarding = true;
  bool _isAuthenticated = false;
  bool _biometricEnabled = false;
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
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

  Future<void> _authenticate() async {
    final localAuth = LocalAuthentication();
    try {
      final isAvailable = await localAuth.canCheckBiometrics;
      final isSupported = await localAuth.isDeviceSupported();
      if (isAvailable && isSupported) {
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
  static const _navLabels = ['Home', 'Transactions', 'Budget', 'Goals', 'Debt', 'Insights'];

  final _screens = const [
    HomeScreen(),
    TransactionsScreen(),
    BudgetScreen(),
    GoalsScreen(),
    DebtScreen(),
    InsightsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    NotificationService.instance.initialize();
    // Register navigation callback for app shortcuts
    registerTabNavigation((tabIndex) {
      ref.read(currentTabProvider.notifier).state = tabIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentTab = ref.watch(currentTabProvider);

    // Listen to pending SMS transactions detected
    ref.listen<ParsedSmsTxn?>(pendingSmsTransactionProvider, (previous, next) {
      if (next != null) {
        _showSmsConfirmationDialog(context, next);
      }
    });

    // Schedule notifications when transactions change
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
        body: AnimatedSwitcher(
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
          child: _screens[currentTab],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.08),
                width: 0.5,
              ),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: currentTab,
            onTap: (i) {
              HapticFeedback.selectionClick();
              ref.read(currentTabProvider.notifier).state = i;
            },
            type: BottomNavigationBarType.fixed,
            items: [
              _navItem(LucideIcons.house, LucideIcons.house, 0),
              _navItem(LucideIcons.receipt, LucideIcons.receipt, 1),
              _navItem(LucideIcons.wallet, LucideIcons.wallet, 2),
              _navItem(LucideIcons.flag, LucideIcons.flag, 3),
              _navItem(LucideIcons.creditCard, LucideIcons.creditCard, 4),
              _navItem(LucideIcons.chartBar, LucideIcons.chartBar, 5),
            ],
          ),
        ),
        floatingActionButton: currentTab <= 1
            ? FloatingActionButton.extended(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showAddOptions(context);
                },
                icon: const Icon(LucideIcons.plus, size: 20),
                label: const Text('New'),
              )
            : null,
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData outlined, IconData filled, int index) {
    final currentTab = ref.watch(currentTabProvider);
    return BottomNavigationBarItem(
      icon: Icon(currentTab == index ? filled : outlined),
      activeIcon: Icon(filled),
      label: _navLabels[index],
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
              Text('New Transaction', style: AppTheme.displayStyle(size: 18, weight: FontWeight.w600, color: colorScheme.onSurface)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: LucideIcons.plus,
                      label: 'Expense',
                      color: colorScheme.primary,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showAddTransaction(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionButton(
                      icon: LucideIcons.arrowLeftRight,
                      label: 'Transfer',
                      color: AppColors.warning,
                      onTap: () {
                        Navigator.pop(ctx);
                        _showTransfer(context);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: _ActionButton(
                  icon: LucideIcons.arrowRightLeft,
                  label: 'Split Transaction',
                  color: AppColors.tertiary,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSplitTransaction(context);
                  },
                ),
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

  void _showTransfer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const TransferSheet(),
    );
  }

  void _showSplitTransaction(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const SplitTransactionSheet(),
    );
  }

  void _showSmsConfirmationDialog(BuildContext context, ParsedSmsTxn txn) {
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
              style: AppTheme.displayStyle(
                size: 18,
                weight: FontWeight.w600,
              ),
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
                      Text(
                        'Amount',
                        style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant),
                      ),
                      Text(
                        'Category',
                        style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '₹${txn.amount.toStringAsFixed(0)}',
                        style: AppTheme.financialStyle(
                          size: 18,
                          weight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          txn.categoryId.toUpperCase(),
                          style: AppTheme.bodyStyle(
                            size: 11,
                            weight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Note / Merchant',
                    style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    txn.note,
                    style: AppTheme.bodyStyle(
                      size: 13,
                      weight: FontWeight.w500,
                      color: colorScheme.onSurface,
                    ),
                  ),
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
            child: Text(
              'Ignore',
              style: AppTheme.bodyStyle(color: colorScheme.onSurfaceVariant),
            ),
          ),
          FilledButton(
            onPressed: () async {
              if (!ctx.mounted) return;
              final notifier = ref.read(transactionNotifierProvider.notifier);
              
              // Check for duplicates before adding
              final dupCheck = await notifier.checkForDuplicates(
                amount: txn.amount,
                categoryId: txn.categoryId,
                date: txn.date,
                note: txn.note,
              );
              
              if (!ctx.mounted) return;
              if (dupCheck != null && dupCheck.hasDuplicates) {
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
                        Text(
                          'A similar transaction already exists:',
                          style: AppTheme.bodyStyle(size: 14, color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        ...dupCheck.potentialDuplicates.take(3).map((d) => Padding(
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
                        if (dupCheck.potentialDuplicates.length > 3)
                          Text(
                            '...and ${dupCheck.potentialDuplicates.length - 3} more',
                            style: AppTheme.bodyStyle(size: 11, color: colorScheme.onSurfaceVariant),
                          ),
                        const SizedBox(height: 12),
                        Text(
                          'Add it anyway?',
                          style: AppTheme.bodyStyle(size: 14, color: colorScheme.onSurfaceVariant),
                        ),
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
            child: Text(
              'Add Expense',
              style: AppTheme.bodyStyle(weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: widget.color.withValues(alpha: 0.1),
            border: Border.all(color: widget.color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 28, color: widget.color),
              const SizedBox(height: 8),
              Text(
              widget.label,
              style: AppTheme.bodyStyle(
                size: 13,
                weight: FontWeight.w600,
                color: widget.color,
              ),
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
                child: Icon(
                  LucideIcons.lock,
                  size: 40,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'BudgetLite Locked',
                style: AppTheme.displayStyle(
                  size: 22,
                  weight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please unlock with your biometric credentials to manage your budget.',
                textAlign: TextAlign.center,
                style: AppTheme.bodyStyle(
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(LucideIcons.fingerprint),
                label: const Text('Tap to Unlock'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
