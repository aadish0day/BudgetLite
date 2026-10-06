import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/database.dart';
import '../../core/services/sms_listener_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/colors.dart';
import '../../core/utils/constants.dart';
import '../../core/utils/demo_data.dart';
import '../../core/utils/icon_helper.dart';
import '../../core/utils/sms_parser.dart';
import '../../providers/budget_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../sms/sms_review_queue_screen.dart';
import 'auto_category_rules_sheet.dart';
import 'csv_import_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  StreamSubscription<SmsMessage>? _smsSub;

  @override
  void dispose() {
    _smsSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final biometricLock =
        ref.watch(biometricLockEnabledProvider).valueOrNull ?? false;
    final smsParsing =
        ref.watch(smsParsingEnabledProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppConstants.appName,
          style: AppTheme.displayStyle(size: 17),
        ),
      ),
      body: ListView(
        padding: AppConstants.screenPadding,
        children: [
          const _SectionHeader(title: 'Appearance'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: colorScheme.primary.withValues(alpha: 0.1),
                          ),
                          child: Icon(
                            LucideIcons.sunMedium,
                            size: 20,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Theme Mode',
                                style: AppTheme.bodyStyle(
                                  size: 15,
                                  weight: FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                'Choose light, dark, or system theme',
                                style: AppTheme.bodyStyle(
                                  size: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Consumer(
                      builder: (context, ref, _) {
                        final themeOption =
                            ref.watch(themeModeProvider).valueOrNull ??
                            ThemeModeOption.light;
                        return SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeModeOption>(
                            segments: const [
                              ButtonSegment(
                                value: ThemeModeOption.light,
                                icon: Icon(LucideIcons.sun, size: 14),
                                label: Text('Light'),
                              ),
                              ButtonSegment(
                                value: ThemeModeOption.dark,
                                icon: Icon(LucideIcons.moon, size: 14),
                                label: Text('Dark'),
                              ),
                              ButtonSegment(
                                value: ThemeModeOption.system,
                                icon: Icon(LucideIcons.monitor, size: 14),
                                label: Text('System'),
                              ),
                            ],
                            selected: {themeOption},
                            onSelectionChanged: (selected) {
                              if (selected.isNotEmpty) {
                                ref
                                    .read(settingsNotifierProvider.notifier)
                                    .setThemeMode(selected.first);
                              }
                            },
                            style: const ButtonStyle(
                              visualDensity: VisualDensity(horizontal: -1),
                              tapTargetSize: MaterialTapTargetSize.padded,
                              minimumSize: WidgetStatePropertyAll(Size(0, 44)),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 56),
              _SettingTile(
                icon: LucideIcons.eyeOff,
                title: 'Hide Balances',
                subtitle: 'Obscure balances on the home screen',
                trailing: Consumer(
                  builder: (context, ref, _) {
                    final hidden =
                        ref.watch(balanceHiddenProvider).valueOrNull ?? false;
                    return Switch.adaptive(
                      value: hidden,
                      onChanged: (v) {
                        ref
                            .read(settingsNotifierProvider.notifier)
                            .setBalanceHidden(v);
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1, indent: 56),
              _SettingTile(
                icon: LucideIcons.palette,
                title: 'Accent Color',
                subtitle: 'Change app primary color with live preview',
                trailing: Consumer(
                  builder: (context, ref, _) {
                    final accentVal = ref
                        .watch(accentColorProvider)
                        .valueOrNull;
                    final color = accentVal != null
                        ? Color(accentVal)
                        : AppColors.primary;
                    return Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
                onTap: () => _showAccentColorPicker(context, ref),
              ),
              const Divider(height: 1, indent: 56),
              _SettingTile(
                icon: LucideIcons.tags,
                title: 'Manage Categories',
                subtitle: 'Add, edit, or delete categories safely',
                trailing: const Icon(LucideIcons.chevronRight),
                onTap: () => _showManageCategoriesSheet(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'App Modules'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingTile(
                icon: LucideIcons.wallet,
                title: 'Budget Module',
                subtitle: 'Enable or hide the Budget tab & features',
                trailing: Consumer(
                  builder: (context, ref, _) {
                    final enabled =
                        ref.watch(budgetModuleEnabledProvider).valueOrNull ??
                        true;
                    return Switch.adaptive(
                      value: enabled,
                      onChanged: (v) {
                        ref
                            .read(settingsNotifierProvider.notifier)
                            .setBudgetModuleEnabled(v);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Security'),
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
              Opacity(
                opacity: biometricLock ? 1.0 : 0.4,
                child: _SettingTile(
                  icon: LucideIcons.timer,
                  title: 'Auto-lock timer',
                  subtitle: biometricLock
                      ? 'Require auth after being backgrounded'
                      : 'Inert (Biometric lock is OFF)',
                  trailing: Consumer(
                    builder: (context, ref, _) {
                      final duration =
                          ref.watch(autoLockDurationProvider).valueOrNull ?? 1;
                      return DropdownButton<int>(
                        value: duration,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: 0,
                            child: Text('Immediately'),
                          ),
                          DropdownMenuItem(value: 1, child: Text('1 min')),
                          DropdownMenuItem(value: 5, child: Text('5 min')),
                          DropdownMenuItem(value: 15, child: Text('15 min')),
                        ],
                        onChanged: biometricLock
                            ? (val) {
                                if (val != null) {
                                  ref
                                      .read(settingsNotifierProvider.notifier)
                                      .setAutoLockDuration(val);
                                }
                              }
                            : null,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'SMS Tracking & Simulation'),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: AppColors.warning.withValues(alpha: 0.15),
                            ),
                            child: Text(
                              '${queue.length}',
                              style: AppTheme.bodyStyle(
                                size: 11,
                                weight: FontWeight.w700,
                                color: AppColors.warning,
                              ),
                            ),
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
          const _SectionHeader(title: 'Auto-Categorization'),
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
              const Divider(height: 1, indent: 56),
              Consumer(
                builder: (context, ref, _) {
                  final enabled =
                      ref.watch(smsAutoNoteEnabledProvider).valueOrNull ?? true;
                  return SwitchListTile(
                    value: enabled,
                    onChanged: (val) {
                      ref
                          .read(settingsNotifierProvider.notifier)
                          .setSmsAutoNoteEnabled(val);
                    },
                    title: Text(
                      'Auto-fill Merchant in Notes',
                      style: AppTheme.bodyStyle(weight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      'Include payee/merchant name in transaction note',
                      style: AppTheme.bodyStyle(
                        size: 11,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    secondary: const Icon(LucideIcons.fileText, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Notifications'),
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
          const _SectionHeader(title: 'Data & Local Storage'),
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
                trailing: const Icon(
                  LucideIcons.chevronRight,
                  color: Colors.red,
                ),
                onTap: () => _showResetConfirmation(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'About'),
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

  Future<void> _toggleBiometricLock(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final localAuth = LocalAuthentication();
    if (enable) {
      try {
        final isSupported = await localAuth.isDeviceSupported();
        final canCheck = await localAuth.canCheckBiometrics;
        if (isSupported || canCheck) {
          final authenticated = await localAuth.authenticate(
            localizedReason: 'Verify identity to enable lock',
          );
          if (authenticated) {
            await ref
                .read(settingsNotifierProvider.notifier)
                .setBiometricLock(true);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Biometric lock enabled successfully!'),
                ),
              );
            }
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'No biometrics or device PIN enrolled on this device',
                ),
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Biometric auth: ${e.toString().split('\n').first}',
              ),
            ),
          );
        }
      }
    } else {
      try {
        final isSupported = await localAuth.isDeviceSupported();
        final canCheck = await localAuth.canCheckBiometrics;
        if (isSupported || canCheck) {
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
            SnackBar(
              content: Text(
                'Authentication failed: ${e.toString().split('\n').first}',
              ),
            ),
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

  Future<void> _toggleSmsParsing(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
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
            const SnackBar(
              content: Text(
                'SMS transaction tracking enabled — listening for UPI messages',
              ),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('SMS permission denied. Cannot enable tracking.'),
            ),
          );
        }
      }
    } else {
      await ref.read(settingsNotifierProvider.notifier).setSmsParsing(false);
      unawaited(_smsSub?.cancel());
      _smsSub = null;
      await SmsListenerService().stopListening();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('SMS tracking disabled')));
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
    final colorScheme = Theme.of(context).colorScheme;
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
            const SnackBar(
              content: Text('SMS permission required to scan inbox'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    final messages = await listener.scanInbox();
    if (!context.mounted) return;

    if (messages.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No UPI SMS found in inbox'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Build keyword→category map from user's auto-categorization rules
    final userRules = ref.read(autoCategorizationRulesProvider);
    final Map<String, String> keywordToCategory = {};
    for (final rule in userRules) {
      keywordToCategory[rule.keyword.toLowerCase()] = rule.categoryId;
    }

    int totalSmsParsed = 0;
    final queueNotifier = ref.read(smsReviewQueueProvider.notifier);
    final includeMerchantNote =
        ref.read(smsAutoNoteEnabledProvider).valueOrNull ?? true;

    for (final sms in messages) {
      final parsedTxn = SmsParser.parseMessage(
        sms.body,
        keywordToCategory: keywordToCategory.isNotEmpty
            ? keywordToCategory
            : null,
        dateOverride: DateTime.fromMillisecondsSinceEpoch(
          sms.timestamp,
          isUtc: true,
        ).toLocal(),
        includeMerchantNote: includeMerchantNote,
      );
      if (parsedTxn != null) {
        totalSmsParsed++;
        if (!queueNotifier.isAlreadyInQueue(parsedTxn.id)) {
          await queueNotifier.addToQueue(parsedTxn, force: true);
        }
      }
    }

    if (context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();

      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 3),
          content: Text(
            'Found $totalSmsParsed UPI transaction${totalSmsParsed == 1 ? "" : "s"} — added to Review Queue!',
            style: AppTheme.bodyStyle(
              size: 13,
              weight: FontWeight.w500,
              color: colorScheme.onSurface,
            ),
          ),
          backgroundColor: colorScheme.surfaceContainerHighest,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.12),
            ),
          ),
          action: SnackBarAction(
            label: 'VIEW QUEUE',
            textColor: colorScheme.primary,
            onPressed: messenger.hideCurrentSnackBar,
          ),
        ),
      );

      // Automatically open Review Queue screen so user can review all items immediately
      unawaited(
        Navigator.of(context)
            .push(
              MaterialPageRoute(builder: (_) => const SmsReviewQueueScreen()),
            )
            .then((_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              }
            }),
      );
    }
  }

  void _processSmsBody(WidgetRef ref, String body, {int? timestamp}) {
    final userRules = ref.read(autoCategorizationRulesProvider);
    final Map<String, String> keywordToCategory = {};
    for (final rule in userRules) {
      keywordToCategory[rule.keyword.toLowerCase()] = rule.categoryId;
    }
    final includeMerchantNote =
        ref.read(smsAutoNoteEnabledProvider).valueOrNull ?? true;

    final parsedTxn = SmsParser.parseMessage(
      body,
      keywordToCategory: keywordToCategory.isNotEmpty
          ? keywordToCategory
          : null,
      dateOverride: timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(
              timestamp,
              isUtc: true,
            ).toLocal()
          : null,
      includeMerchantNote: includeMerchantNote,
    );
    if (parsedTxn != null) {
      ref.read(smsReviewQueueProvider.notifier).addToQueue(parsedTxn);
      ref.read(pendingSmsTransactionProvider.notifier).state = parsedTxn;
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

    final randomSms =
        mockSmsList[DateTime.now().millisecond % mockSmsList.length];
    final parsed = SmsParser.parseMessage(
      randomSms,
      keywordToCategory: keywordToCategory.isNotEmpty
          ? keywordToCategory
          : null,
    );
    if (parsed != null) {
      queueNotifier.addToQueue(parsed);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Simulated SMS added to review queue (${queueNotifier.pendingCount} pending)',
          ),
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
            Text('Notification Threshold', style: AppTheme.displayStyle()),
            const SizedBox(height: 16),
            Text(
              'Get notified when spending crosses this percentage of your budget',
              style: AppTheme.bodyStyle(
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
      final path = await ref
          .read(settingsNotifierProvider.notifier)
          .exportDatabase();
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _restoreData(BuildContext context, WidgetRef ref) async {
    try {
      final result = await FilePicker.pickFiles();
      if (result.isNotEmpty && result.first.path != null) {
        final path = result.first.path!;
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }

  void _showSmsReviewQueue(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SmsReviewQueueScreen()));
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
        content: const Text(
          'This will replace all your current transactions with sample data. Continue?',
        ),
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
          content: Text(
            'Demo data loaded! Explore the app with sample transactions.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showManageCategoriesSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ManageCategoriesSheet(),
    );
  }

  void _showAccentColorPicker(BuildContext context, WidgetRef ref) {
    final colors = [
      AppColors.primary,
      const Color(0xFF10B981), // Emerald
      const Color(0xFF0D7377), // Teal
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Crimson
    ];

    Color selectedColor = Color(
      ref.read(accentColorProvider).valueOrNull ?? AppColors.primary.toARGB32(),
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'Select Accent Color',
              style: AppTheme.displayStyle(size: 16),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Preview',
                    style: AppTheme.bodyStyle(
                      size: 11,
                      weight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── Live Preview Sample Card ──
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: selectedColor.withValues(alpha: 0.1),
                      border: Border.all(
                        color: selectedColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              LucideIcons.wallet,
                              size: 18,
                              color: selectedColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sample Balance',
                              style: AppTheme.bodyStyle(
                                size: 12,
                                weight: FontWeight.w600,
                                color: selectedColor,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: selectedColor,
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '₹12,450',
                          style: AppTheme.financialStyle(
                            size: 22,
                            weight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pick Color Swatch',
                    style: AppTheme.bodyStyle(
                      size: 11,
                      weight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: colors.map((color) {
                      final isSelected =
                          selectedColor.toARGB32() == color.toARGB32();
                      return GestureDetector(
                        onTap: () => setState(() => selectedColor = color),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 20,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await ref
                      .read(settingsNotifierProvider.notifier)
                      .setAccentColor(selectedColor.toARGB32());
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(
                    LucideIcons.triangleAlert,
                    color: AppColors.error,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Reset All Data',
                    style: AppTheme.displayStyle(
                      size: 16,
                      weight: FontWeight.w700,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This action is irreversible! It will delete ALL transactions, budgets, goals, tags, settings, AND recurring transaction rules.',
                      style: AppTheme.bodyStyle(
                        size: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Type "RESET" to confirm deletion:',
                      style: AppTheme.bodyStyle(
                        size: 12,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      onChanged: (val) => setState(() => typedText = val),
                      decoration: InputDecoration(
                        hintText: 'RESET',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error,
                  ),
                  onPressed: typedText.trim() == 'RESET'
                      ? () async {
                          Navigator.pop(ctx);
                          final db = ref.read(databaseProvider);
                          await db.clearAllData();
                          unawaited(
                            ref.read(smsReviewQueueProvider.notifier).clear(),
                          );

                          ref.invalidate(transactionsProvider);
                          ref.invalidate(thisMonthTransactionsProvider);
                          ref.invalidate(totalSpentThisMonthProvider);
                          ref.invalidate(totalIncomeThisMonthProvider);
                          ref.invalidate(thisMonthBudgetsProvider);
                          ref.invalidate(monthlyIncomeProvider);
                          ref.invalidate(categoriesProvider);
                          ref.invalidate(expenseCategoriesProvider);
                          ref.invalidate(settingsProvider);
                          ref.invalidate(initialBalanceProvider);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'All data and settings have been completely reset.',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      : null,
                  child: const Text('Delete Everything'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ManageCategoriesSheet extends ConsumerWidget {
  const _ManageCategoriesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? [];
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Manage Categories', style: AppTheme.displayStyle()),
              IconButton(
                icon: const Icon(LucideIcons.x),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: categories.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final cat = categories[idx];
                final color = Color(cat.color);
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        getCategoryIcon(cat.icon),
                        color: color,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      cat.name,
                      style: AppTheme.bodyStyle(weight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      cat.type.toUpperCase(),
                      style: AppTheme.bodyStyle(
                        size: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Edit ${cat.name}',
                          icon: const Icon(LucideIcons.pencil, size: 20),
                          onPressed: () =>
                              _showEditCategoryDialog(context, ref, cat),
                        ),
                        IconButton(
                          tooltip: 'Delete ${cat.name}',
                          icon: const Icon(
                            LucideIcons.trash2,
                            size: 20,
                            color: AppColors.error,
                          ),
                          onPressed: () => _deleteCategorySafely(
                            context,
                            ref,
                            cat,
                            categories,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(LucideIcons.plus),
            label: const Text('Add New Category'),
            onPressed: () => _showAddCategoryDialog(context, ref),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(context: context, builder: (ctx) => const _AddCategoryDialog());
  }

  void _showEditCategoryDialog(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => _EditCategoryDialog(category: category),
    );
  }

  Future<void> _deleteCategorySafely(
    BuildContext context,
    WidgetRef ref,
    Category category,
    List<Category> allCategories,
  ) async {
    final db = ref.read(databaseProvider);
    final txnCount = await db.getTransactionCountForCategory(category.id);
    final remaining = allCategories.where((c) => c.id != category.id).toList();

    if (remaining.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot delete the only category in the app.'),
          ),
        );
      }
      return;
    }

    if (txnCount > 0) {
      String targetCategoryId = remaining.first.id;
      if (!context.mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setState) => AlertDialog(
            title: Text('Reassign Transactions ($txnCount)'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category "${category.name}" has $txnCount existing transaction(s). Select a category to reassign them to before deleting:',
                    style: AppTheme.bodyStyle(size: 13),
                  ),
                  const SizedBox(height: 14),
                  DropdownButton<String>(
                    value: targetCategoryId,
                    isExpanded: true,
                    items: remaining
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => targetCategoryId = val);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reassign & Delete'),
              ),
            ],
          ),
        ),
      );

      if (confirmed == true) {
        await db.deleteCategoryWithReassignment(category.id, targetCategoryId);
        ref.invalidate(categoriesProvider);
        ref.invalidate(expenseCategoriesProvider);
        ref.invalidate(transactionsProvider);
        ref.invalidate(thisMonthTransactionsProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Category "${category.name}" deleted and $txnCount transactions reassigned.',
              ),
            ),
          );
        }
      }
    } else {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Delete "${category.name}"?'),
          content: const Text(
            'This category has no transactions. Are you sure you want to delete it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await db.deleteCategoryWithReassignment(
          category.id,
          remaining.first.id,
        );
        ref.invalidate(categoriesProvider);
        ref.invalidate(expenseCategoriesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Category "${category.name}" deleted.')),
          );
        }
      }
    }
  }
}

class _AddCategoryDialog extends ConsumerStatefulWidget {
  const _AddCategoryDialog();

  @override
  ConsumerState<_AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends ConsumerState<_AddCategoryDialog> {
  late final TextEditingController _nameCtrl;
  String _selectedType = 'expense';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Category Name'),
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              value: _selectedType,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'expense', child: Text('Expense')),
                DropdownMenuItem(value: 'income', child: Text('Income')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            final db = ref.read(databaseProvider);
            final id = 'cat_${DateTime.now().millisecondsSinceEpoch}';
            await db
                .into(db.categories)
                .insert(
                  CategoriesCompanion.insert(
                    id: id,
                    name: name,
                    type: Value(_selectedType),
                    color: const Value(0xFF3B82F6),
                    icon: const Value('tag'),
                  ),
                );
            ref.invalidate(categoriesProvider);
            ref.invalidate(expenseCategoriesProvider);
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _EditCategoryDialog extends ConsumerStatefulWidget {
  const _EditCategoryDialog({required this.category});
  final Category category;

  @override
  ConsumerState<_EditCategoryDialog> createState() =>
      _EditCategoryDialogState();
}

class _EditCategoryDialogState extends ConsumerState<_EditCategoryDialog> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.category.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Category'),
      content: TextField(
        controller: _nameCtrl,
        decoration: const InputDecoration(labelText: 'Category Name'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final newName = _nameCtrl.text.trim();
            if (newName.isEmpty) return;
            final db = ref.read(databaseProvider);
            await (db.update(db.categories)
                  ..where((c) => c.id.equals(widget.category.id)))
                .write(CategoriesCompanion(name: Value(newName)));
            ref.invalidate(categoriesProvider);
            ref.invalidate(expenseCategoriesProvider);
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

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
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.cardRadiusSmall),
          boxShadow: isDark
              ? AppColors.cardShadowDark
              : AppColors.cardShadowLight,
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: ListTile(
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
      ),
    );
  }
}
