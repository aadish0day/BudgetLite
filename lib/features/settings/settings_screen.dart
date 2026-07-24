import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/sms_parser.dart';
import '../../core/utils/demo_data.dart';
import '../../services/sms_listener_service.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/budget_provider.dart';
import 'csv_import_sheet.dart';
import 'auto_category_rules_sheet.dart';
import '../sms/sms_review_queue_screen.dart';

/// Global subscription for real-time SMS events.
/// Managed at top level because SettingsScreen is a ConsumerWidget (not stateful).
StreamSubscription<dynamic>? _smsSub;

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final darkMode = ref.watch(darkModeProvider).valueOrNull ?? false;
    final biometricLock = ref.watch(biometricLockEnabledProvider).valueOrNull ?? false;
    final smsParsing = ref.watch(smsParsingEnabledProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppConstants.appName,
          style: AppTheme.displayStyle(
            size: 17,
            weight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView(
        padding: AppConstants.screenPadding,
        children: [
          _SectionHeader(title: 'Appearance'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingTile(
                icon: LucideIcons.moon,
                title: 'Dark Mode',
                subtitle: 'Switch to dark theme',
                trailing: Switch.adaptive(
                  value: darkMode,
                  onChanged: (v) {
                    ref.read(settingsNotifierProvider.notifier).setDarkMode(v);
                  },
                ),
              ),
              const Divider(height: 1, indent: 56),
              _SettingTile(
                icon: LucideIcons.eyeOff,
                title: 'Hide Balances',
                subtitle: 'Obscure balances on the home screen',
                trailing: Consumer(builder: (context, ref, _) {
                  final hidden = ref.watch(balanceHiddenProvider).valueOrNull ?? false;
                  return Switch.adaptive(
                    value: hidden,
                    onChanged: (v) {
                      ref.read(settingsNotifierProvider.notifier).setBalanceHidden(v);
                    },
                  );
                }),
              ),
              const Divider(height: 1, indent: 56),
              _SettingTile(
                icon: LucideIcons.palette,
                title: 'Accent Color',
                subtitle: 'Change app primary color',
                trailing: Consumer(builder: (context, ref, _) {
                  final accentVal = ref.watch(accentColorProvider).valueOrNull;
                  final color = accentVal != null ? Color(accentVal) : AppColors.primary;
                  return Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  );
                }),
                onTap: () => _showAccentColorPicker(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Security'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingTile(
                icon: LucideIcons.fingerprint,
                title: 'Biometric Lock',
                subtitle: 'Secure app access with fingerprint',
                trailing: Switch.adaptive(
                  value: biometricLock,
                  onChanged: (v) => _toggleBiometricLock(context, ref, v),
                ),
              ),
              const Divider(height: 1, indent: 56),
              _SettingTile(
                icon: LucideIcons.timer,
                title: 'Auto-lock timer',
                subtitle: 'Require auth after being backgrounded',
                trailing: Consumer(builder: (context, ref, _) {
                  final duration = ref.watch(autoLockDurationProvider).valueOrNull ?? 1;
                  return DropdownButton<int>(
                    value: duration,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Immediately')),
                      DropdownMenuItem(value: 1, child: Text('1 min')),
                      DropdownMenuItem(value: 5, child: Text('5 min')),
                      DropdownMenuItem(value: 15, child: Text('15 min')),
                    ],
                    onChanged: biometricLock ? (val) {
                      if (val != null) {
                        ref.read(settingsNotifierProvider.notifier).setAutoLockDuration(val);
                      }
                    } : null,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'SMS Tracking & Simulation'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingTile(
                icon: LucideIcons.messageSquare,
                title: 'Auto SMS Parsing',
                subtitle: 'Detect bank SMS transactions (Android)',
                trailing: Switch.adaptive(
                  value: smsParsing,
                  onChanged: (v) => _toggleSmsParsing(context, ref, v),
                ),
              ),
              const Divider(height: 1, indent: 56),
              _SettingTile(
                icon: LucideIcons.inbox,
                title: 'Review Queue',
                subtitle: 'Pending SMS transactions awaiting confirmation',
                trailing: Consumer(
                  builder: (ctx, ref, _) {
                    final queue = ref.watch(smsReviewQueueProvider);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (queue.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.warning.withValues(alpha: 0.15),
                            ),
                            child: Text('${queue.length}',
                                style: AppTheme.bodyStyle(
                                  size: 11, weight: FontWeight.w700, color: AppColors.warning)),
                          ),
                        const SizedBox(width: 6),
                        const Icon(LucideIcons.chevronRight, size: 16),
                      ],
                    );
                  },
                ),
                onTap: () => _showSmsReviewQueue(context),
              ),
              const Divider(height: 1, indent: 56),
              _SettingTile(
                icon: LucideIcons.search,
                title: 'Scan SMS Inbox',
                subtitle: 'Import existing UPI SMS from your messages',
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _scanSmsInbox(context, ref),
              ),
              const Divider(height: 1, indent: 56),
              _SettingTile(
                icon: LucideIcons.creditCard,
                title: 'Simulate Bank SMS',
                subtitle: 'Trigger a mock bank SMS notification',
                trailing: const Icon(LucideIcons.play),
                onTap: () => _simulateSms(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Auto-Categorization'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingTile(
                icon: LucideIcons.brainCircuit,
                title: 'Keyword Rules',
                subtitle: 'Edit auto-category keyword mappings',
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _showAutoCategoryRules(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Notifications'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingTile(
                icon: LucideIcons.bell,
                title: 'Overspend Alert',
                subtitle: 'Notify when crossing 90% of budget',
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _showThresholdPicker(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Data'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingTile(
                icon: LucideIcons.upload,
                title: 'Export Database',
                subtitle: 'Save a backup of your data',
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _exportData(context, ref),
              ),
              const Divider(height: 1, indent: 56),
              _SettingTile(
                icon: LucideIcons.download,
                title: 'Restore from Backup',
                subtitle: 'Import a previously saved backup',
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _restoreData(context, ref),
              ),
              const Divider(height: 1, indent: 56),
              _SettingTile(
                icon: LucideIcons.fileSpreadsheet,
                title: 'Import Bank Statement',
                subtitle: 'Import transactions from a CSV bank statement',
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _showCsvImport(context),
              ),
              const Divider(height: 1, indent: 56),
              _SettingTile(
                icon: LucideIcons.flaskConical,
                title: 'Load Demo Data',
                subtitle: 'Populate with sample transactions for testing',
                trailing: const Icon(LucideIcons.play),
                onTap: () => _seedDemoData(context, ref),
              ),
              const Divider(height: 1, indent: 56),
              _SettingTile(
                icon: LucideIcons.trash2,
                title: 'Reset All Data',
                subtitle: 'Delete all transactions and settings',
                trailing: const Icon(LucideIcons.chevronRight, color: Colors.red),
                onTap: () => _showResetConfirmation(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'About'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingTile(
                icon: LucideIcons.info,
                title: 'Version',
                subtitle: '1.0.0',
                trailing: Text(
                  '1.0.0',
                  style: AppTheme.bodyStyle(
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _toggleBiometricLock(BuildContext context, WidgetRef ref, bool enable) async {
    final localAuth = LocalAuthentication();
    if (enable) {
      try {
        final canCheck = await localAuth.canCheckBiometrics;
        final isSupported = await localAuth.isDeviceSupported();
        if (canCheck && isSupported) {
          final authenticated = await localAuth.authenticate(
            localizedReason: 'Verify identity to enable lock',
          );
          if (authenticated) {
            await ref.read(settingsNotifierProvider.notifier).setBiometricLock(true);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Biometric lock enabled successfully!')),
              );
            }
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometrics not supported on this device')),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to enable biometrics: $e')),
          );
        }
      }
    } else {
      try {
        final canCheck = await localAuth.canCheckBiometrics;
        final isSupported = await localAuth.isDeviceSupported();
        if (canCheck && isSupported) {
          final authenticated = await localAuth.authenticate(
            localizedReason: 'Verify identity to disable lock',
          );
          if (!authenticated) {
            return;
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to authenticate: $e')),
          );
        }
        return;
      }
      await ref.read(settingsNotifierProvider.notifier).setBiometricLock(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric lock disabled')),
        );
      }
    }
  }

  Future<void> _toggleSmsParsing(BuildContext context, WidgetRef ref, bool enable) async {
    if (enable) {
      final status = await Permission.sms.request();
      if (status.isGranted) {
        await ref.read(settingsNotifierProvider.notifier).setSmsParsing(true);
        // Start real SMS listener
        final listener = SmsListenerService();
        final nativeGranted = await listener.isPermissionGranted();
        if (!nativeGranted) await listener.requestPermission();
        await listener.startListening();
        _bindSmsListener(ref);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS transaction tracking enabled — listening for UPI messages')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS permission denied. Cannot enable tracking.')),
          );
        }
      }
    } else {
      await ref.read(settingsNotifierProvider.notifier).setSmsParsing(false);
      await SmsListenerService().stopListening();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS tracking disabled')),
        );
      }
    }
  }

  void _bindSmsListener(WidgetRef ref) {
    _smsSub?.cancel();
    _smsSub = SmsListenerService().onSmsReceived.listen((sms) {
      _processSmsBody(ref, sms.body, timestamp: sms.timestamp);
    });
  }

  Future<void> _scanSmsInbox(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final listener = SmsListenerService();

    final granted = await listener.isPermissionGranted();
    if (!granted) {
      await listener.requestPermission();
      await Future.delayed(const Duration(milliseconds: 500));
      final checkAgain = await listener.isPermissionGranted();
      if (!checkAgain) {
        if (context.mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('SMS permission required to scan inbox'),
                behavior: SnackBarBehavior.floating),
          );
        }
        return;
      }
    }

    final messages = await listener.scanInbox();
    if (!context.mounted) return;

    if (messages.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No UPI SMS found in inbox'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    // Build keyword→category map from user's auto-categorization rules
    final userRules = ref.read(autoCategorizationRulesProvider);
    final Map<String, String> keywordToCategory = {};
    for (final rule in userRules) {
      keywordToCategory[rule.keyword.toLowerCase()] = rule.categoryId;
    }

    int parsed = 0;
    final queueNotifier = ref.read(smsReviewQueueProvider.notifier);
    final pendingBefore = queueNotifier.pendingCount;

    for (final sms in messages) {
      final parsedTxn = SmsParser.parseMessage(
        sms.body,
        keywordToCategory: keywordToCategory.isNotEmpty ? keywordToCategory : null,
        dateOverride: DateTime.fromMillisecondsSinceEpoch(sms.timestamp, isUtc: true).toLocal(),
      );
      if (parsedTxn != null) {
        queueNotifier.addToQueue(parsedTxn);
        parsed++;
      }
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text('Found $parsed UPI transaction${parsed != 1 ? 's' : ''} '
            '(${queueNotifier.pendingCount - pendingBefore} new in review queue)'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _processSmsBody(WidgetRef ref, String body, {int? timestamp}) {
    final userRules = ref.read(autoCategorizationRulesProvider);
    final Map<String, String> keywordToCategory = {};
    for (final rule in userRules) {
      keywordToCategory[rule.keyword.toLowerCase()] = rule.categoryId;
    }

    final parsedTxn = SmsParser.parseMessage(
      body,
      keywordToCategory: keywordToCategory.isNotEmpty ? keywordToCategory : null,
      dateOverride: timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true).toLocal()
          : null,
    );
    if (parsedTxn != null) {
      ref.read(smsReviewQueueProvider.notifier).addToQueue(parsedTxn);
    }
  }

  void _simulateSms(BuildContext context, WidgetRef ref) {
    final queueNotifier = ref.read(smsReviewQueueProvider.notifier);
    // Build keyword→category map from user's auto-categorization rules
    final userRules = ref.read(autoCategorizationRulesProvider);
    final Map<String, String> keywordToCategory = {};
    for (final rule in userRules) {
      keywordToCategory[rule.keyword.toLowerCase()] = rule.categoryId;
    }
    final mockSmsList = [
      'Dear SBI Customer, your A/c X1234 has been debited by Rs. 540.00 at SWIGGY on 22-07-2026. Ref: 62234125',
      'Transaction alert: Rs. 12000.00 debited from HDFC Bank Card ending 4321 at HOUSING SOCIETY on 22/07/2026.',
      'Alert: Spent INR 499.00 on Netflix Recharge at NETFLIX via Netbanking.',
      'Thank you for using Paytm. Rs 1499 spent at ZARA store on 22-07-2026.',
      'Your card was charged Rs 350.00 at STARBUCKS. Remaining balance Rs 45000.',
      'Rs. 4500 spent on Amazon.in. Txn id: 9812471',
      'Your GPay credit of Rs. 8,000.00 received from PARENTS. UPI Ref: 9247128471',
      'Dear User, Rs. 8000 credited to your account by PARENTS. UPI: 928471247',
    ];
    
    final randomSms = mockSmsList[DateTime.now().millisecond % mockSmsList.length];
    final parsed = SmsParser.parseMessage(
      randomSms,
      keywordToCategory: keywordToCategory.isNotEmpty ? keywordToCategory : null,
    );
    if (parsed != null) {
      queueNotifier.addToQueue(parsed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Simulated SMS added to review queue (${queueNotifier.pendingCount} pending)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not parse SMS — unrecognized format'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showThresholdPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Notification Threshold',
          style: AppTheme.displayStyle(
            size: 18,
            weight: FontWeight.w600,
          ),
            ),
            const SizedBox(height: 16),
            Text(
              'Get notified when spending crosses this percentage of your budget',
              style: AppTheme.bodyStyle(
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      final path = await ref.read(settingsNotifierProvider.notifier).exportDatabase();
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _restoreData(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        if (!path.endsWith('.db')) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invalid backup file. Please select a .db file.'),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
          return;
        }
        await ref.read(settingsNotifierProvider.notifier).importDatabase(path);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Database restored successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Restore failed: $e')),
        );
      }
    }
  }

  void _showSmsReviewQueue(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SmsReviewQueueScreen(),
      ),
    );
  }

  void _showAutoCategoryRules(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AutoCategoryRulesSheet(),
    );
  }

  void _showCsvImport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const CsvImportSheet(),
    );
  }

  Future<void> _seedDemoData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Demo Data'),
        content: const Text('This will replace all your current transactions with sample data. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Load Demo Data'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final db = ref.read(databaseProvider);
    await DemoDataSeeder.seed(db);
    ref.invalidate(transactionsProvider);
    ref.invalidate(thisMonthTransactionsProvider);
    ref.invalidate(totalSpentThisMonthProvider);
    ref.invalidate(totalIncomeThisMonthProvider);
    ref.invalidate(thisMonthBudgetsProvider);
    ref.invalidate(monthlyIncomeProvider);
    ref.invalidate(categoriesProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Demo data loaded! Explore the app with sample transactions.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showAccentColorPicker(BuildContext context, WidgetRef ref) {
    final colors = [
      AppColors.primary,
      Colors.teal,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.pink,
      Colors.orange,
      Colors.amber,
      Colors.green,
      Colors.red,
    ];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Accent Color'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((color) {
            return GestureDetector(
              onTap: () {
                ref.read(settingsNotifierProvider.notifier).setAccentColor(color.toARGB32());
                Navigator.pop(ctx);
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black12),
                ),
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(settingsNotifierProvider.notifier).setAccentColor(AppColors.primary.toARGB32());
              Navigator.pop(ctx);
            },
            child: const Text('Reset'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showResetConfirmation(BuildContext context, WidgetRef ref) {
    String typedText = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Reset All Data', style: TextStyle(color: Colors.red)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Are you sure you want to delete all your data? This cannot be undone. Type "DELETE" to confirm.'),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (val) {
                      setState(() {
                        typedText = val;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'DELETE',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: typedText == 'DELETE' || typedText == 'RESET ALL' ? () async {
                    Navigator.pop(ctx);
                    final db = ref.read(databaseProvider);
                    await db.delete(db.transactions).go();
                    await db.delete(db.categories).go();
                    await db.delete(db.budgets).go();
                    await db.delete(db.goals).go();
                    await db.delete(db.appSettings).go();
await db.transaction(() async {
                      await DemoDataSeeder.seed(db);
                    });
                    ref.invalidate(transactionsProvider);
                    ref.invalidate(thisMonthTransactionsProvider);
                    ref.invalidate(totalSpentThisMonthProvider);
                    ref.invalidate(totalIncomeThisMonthProvider);
                    ref.invalidate(thisMonthBudgetsProvider);
                    ref.invalidate(monthlyIncomeProvider);
                    ref.invalidate(categoriesProvider);
                    ref.invalidate(settingsProvider);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('All data has been reset.')),
                      );
                    }
                  } : null,
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: AppTheme.bodyStyle(
          size: 12,
          weight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        boxShadow: isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
      ),
      child: Column(children: children),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.primary.withValues(alpha: 0.1),
        ),
        child: Icon(icon, size: 20, color: colorScheme.primary),
      ),
      title: Text(
        title,
        style: AppTheme.bodyStyle(
          size: 15,
          weight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTheme.bodyStyle(
          size: 12,
          color: colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }
}
