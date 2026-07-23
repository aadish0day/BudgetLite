import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import 'package:collection/collection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:local_auth/local_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' show Value;
import '../../core/database/database.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/sms_parser.dart';
import '../../core/utils/demo_data.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/budget_provider.dart';
import 'csv_import_sheet.dart';
import 'auto_category_rules_sheet.dart';
import '../sms/sms_review_queue_screen.dart';

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
                icon: LucideIcons.creditCard,
                title: 'Simulate Bank SMS',
                subtitle: 'Trigger a mock bank SMS notification',
                trailing: const Icon(LucideIcons.play),
                onTap: () => _simulateSms(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Accounts'),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              final accounts = ref.watch(accountsListProvider).valueOrNull ?? [];
              return _SettingsCard(
                children: [
                  ...accounts.map((a) => Column(
                    children: [
                      if (accounts.indexOf(a) > 0) const Divider(height: 1, indent: 56),
                      _SettingTile(
                        icon: a.id == 'default' ? LucideIcons.wallet : LucideIcons.creditCard,
                        title: a.name,
                        subtitle: 'Balance: ${Formatters.formatCurrency(a.balance)}',
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(a.currency, style: AppTheme.bodyStyle(size: 12, color: colorScheme.onSurfaceVariant)),
                            const SizedBox(width: 4),
                            const Icon(LucideIcons.chevronRight, size: 16),
                          ],
                        ),
                        onTap: () => _editAccount(context, ref, a),
                      ),
                    ],
                  )),
                  const Divider(height: 1, indent: 56),
                  _SettingTile(
                    icon: LucideIcons.plus,
                    title: 'Add Account',
                    subtitle: 'Create a new account',
                    trailing: const Icon(LucideIcons.chevronRight),
                    onTap: () => _addAccount(context, ref),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Currency'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingTile(
                icon: LucideIcons.coins,
                title: 'Change Currency',
                subtitle: 'Select your preferred currency',
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _showCurrencyPicker(context, ref),
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
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SMS transaction tracking enabled')),
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMS tracking disabled')),
        );
      }
    }
  }

  void _simulateSms(BuildContext context, WidgetRef ref) {
    final queueNotifier = ref.read(smsReviewQueueProvider.notifier);
    final mockSmsList = [
      'Dear SBI Customer, your A/c X1234 has been debited by Rs. 540.00 at SWIGGY on 22-07-2026. Ref: 62234125',
      'Transaction alert: Rs. 12000.00 debited from HDFC Bank Card ending 4321 at HOUSING SOCIETY on 22/07/2026.',
      'Alert: Spent INR 499.00 on Netflix Recharge at NETFLIX via Netbanking.',
      'Thank you for using Paytm. Rs 1499 spent at ZARA store on 22-07-2026.',
      'Your card was charged Rs 350.00 at STARBUCKS. Remaining balance Rs 45000.',
      'Rs. 4500 spent on Amazon.in. Txn id: 9812471',
    ];
    
    final randomSms = mockSmsList[DateTime.now().millisecond % mockSmsList.length];
    final parsed = SmsParser.parseMessage(randomSms);
    if (parsed != null) {
      queueNotifier.addToQueue(parsed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Simulated SMS added to review queue (${queueNotifier.pendingCount} pending)'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref) {
    final currencies = ['INR', 'USD', 'EUR', 'GBP'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'Select Currency',
          style: AppTheme.displayStyle(
            size: 18,
            weight: FontWeight.w600,
          ),
            ),
          ),
          ...currencies.map((c) => ListTile(
                title: Text(c),
                onTap: () {
                  ref.read(settingsNotifierProvider.notifier).setCurrency(c);
                  Navigator.pop(ctx);
                },
              )),
          const SizedBox(height: 16),
        ],
      ),
    );
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

  void _addAccount(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final balanceCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Account Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Initial Balance', prefixText: '₹ '),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final db = ref.read(databaseProvider);
              final uuid = const Uuid().v4();
              await db.into(db.accounts).insert(AccountsCompanion.insert(
                id: uuid,
                name: name,
                balance: Value(double.tryParse(balanceCtrl.text) ?? 0),
              ));
              ref.invalidate(accountsListProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editAccount(BuildContext context, WidgetRef ref, Account account) {
    final nameCtrl = TextEditingController(text: account.name);
    final balanceCtrl = TextEditingController(text: account.balance.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Account Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balanceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Balance', prefixText: '₹ '),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => _deleteAccountWithCheck(context, ref, account),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final db = ref.read(databaseProvider);
              await (db.update(db.accounts)..where((a) => a.id.equals(account.id)))
                  .write(AccountsCompanion(
                name: Value(name),
                balance: Value(double.tryParse(balanceCtrl.text) ?? account.balance),
              ));
              ref.invalidate(accountsListProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAccountWithCheck(BuildContext context, WidgetRef ref, Account account) async {
    final db = ref.read(databaseProvider);

    // Check if the account has linked transactions
    final txnCount = (await (db.select(db.transactions)
      ..where((t) => t.accountId.equals(account.id)))
      .get())
      .length;

    // Find other accounts for potential reassignment
    final allAccounts = await db.select(db.accounts).get();
    final otherAccounts = allAccounts.where((a) => a.id != account.id).toList();

    if (txnCount > 0) {
      // Account has transactions — block deletion, offer reassignment
      if (!context.mounted) return;
      if (otherAccounts.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot delete: no other accounts to reassign transactions to.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      String? selectedTargetId = otherAccounts.first.id;
      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Row(
              children: [
                Icon(LucideIcons.alertTriangle, size: 20, color: AppColors.warning),
                const SizedBox(width: 8),
                Text('Cannot delete "${account.name}"',
                    style: AppTheme.displayStyle(size: 16, weight: FontWeight.w600)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This account has $txnCount transaction${txnCount != 1 ? 's' : ''} linked to it. '
                  'Choose which account to reassign them to:',
                  style: AppTheme.bodyStyle(size: 14),
                ),
                const SizedBox(height: 16),
                // Account dropdown
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedTargetId,
                      isExpanded: true,
                      style: AppTheme.bodyStyle(size: 14, weight: FontWeight.w500),
                      items: otherAccounts.map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('${a.name} (₹${a.balance.toStringAsFixed(0)})',
                                  style: AppTheme.bodyStyle(size: 14)),
                            ),
                          ],
                        ),
                      )).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() => selectedTargetId = v);
                        }
                      },
                    ),
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
                onPressed: () async {
                  if (selectedTargetId == null) return;
                  final target = otherAccounts.firstWhereOrNull((a) => a.id == selectedTargetId);
                  if (target == null) return;
                  await (db.update(db.transactions)
                    ..where((t) => t.accountId.equals(account.id)))
                    .write(TransactionsCompanion(accountId: Value(target.id)));
                  await (db.delete(db.accounts)..where((a) => a.id.equals(account.id))).go();
                  ref.invalidate(accountsListProvider);
                  ref.invalidate(transactionsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);   // pop blocking dialog
                  if (context.mounted) Navigator.pop(context); // pop edit dialog
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('"${account.name}" deleted. $txnCount transactions reassigned to "${target.name}".'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Text('Reassign'),
              ),
            ],
          ),
        ),
      );
    } else {
      // No transactions — delete directly
      await (db.delete(db.accounts)..where((a) => a.id.equals(account.id))).go();
      ref.invalidate(accountsListProvider);
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${account.name}" deleted'),
            behavior: SnackBarBehavior.floating,
          ),
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
