import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/database/database.dart';
import '../core/utils/categorization_rule.dart';
import '../core/utils/accessibility_utils.dart';
import 'database_provider.dart';

final settingsProvider = FutureProvider.family<String?, String>((ref, key) async {
  final db = ref.read(databaseProvider);
  final rows = await (db.select(db.appSettings)..where((t) => t.key.equals(key))).get();
  return rows.isNotEmpty ? rows.first.value : null;
});

enum ThemeModeOption { system, light, dark }

class SettingsNotifier extends StateNotifier<AsyncValue<void>> {
  SettingsNotifier(this.ref) : super(const AsyncData(null));
  final Ref ref;

  Future<void> setSetting(String key, String value) async {
    final db = ref.read(databaseProvider);
    final existing = await (db.select(db.appSettings)..where((t) => t.key.equals(key))).get();

    if (existing.isNotEmpty) {
      await (db.update(db.appSettings)..where((t) => t.key.equals(key)))
          .write(AppSettingsCompanion(value: Value(value)));
    } else {
      await db.into(db.appSettings).insert(AppSettingsCompanion.insert(
        key: key,
        value: value,
      ));
    }
    ref.invalidate(settingsProvider);
  }

  Future<String?> getSetting(String key) async {
    final db = ref.read(databaseProvider);
    final rows = await (db.select(db.appSettings)..where((t) => t.key.equals(key))).get();
    return rows.isNotEmpty ? rows.first.value : null;
  }

  Future<ThemeModeOption> getThemeMode() async {
    final val = await getSetting('theme_mode');
    if (val == 'light') return ThemeModeOption.light;
    if (val == 'dark') return ThemeModeOption.dark;
    if (val == 'system') return ThemeModeOption.system;
    final isDark = await getDarkMode();
    return isDark ? ThemeModeOption.dark : ThemeModeOption.light;
  }

  Future<void> setThemeMode(ThemeModeOption mode) async {
    await setSetting('theme_mode', mode.name);
    await setDarkMode(mode == ThemeModeOption.dark);
    ref.invalidate(themeModeProvider);
    ref.invalidate(darkModeProvider);
  }

  Future<bool> getDarkMode() async {
    final val = await getSetting('dark_mode');
    return val == 'true';
  }

  Future<void> setDarkMode(bool value) async {
    await setSetting('dark_mode', value.toString());
    ref.invalidate(darkModeProvider);
  }

  Future<bool> getBiometricLock() async {
    final val = await getSetting('biometric_lock');
    return val == 'true';
  }

  Future<void> setBiometricLock(bool value) async {
    await setSetting('biometric_lock', value.toString());
    ref.invalidate(biometricLockEnabledProvider);
  }

  Future<bool> getSmsParsing() async {
    final val = await getSetting('sms_parsing');
    return val == 'true';
  }

  Future<void> setSmsParsing(bool value) async {
    await setSetting('sms_parsing', value.toString());
    ref.invalidate(smsParsingEnabledProvider);
  }

  Future<double> getNotificationThreshold() async {
    final val = await getSetting('notification_threshold');
    return double.tryParse(val ?? '') ?? 90;
  }

  Future<void> setNotificationThreshold(double value) async {
    await setSetting('notification_threshold', value.toString());
  }

  Future<String> exportDatabase() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'budget_lite.db'));
    if (!await file.exists()) throw Exception('Database not found');

    final exportDir = await getTemporaryDirectory();
    final exportFile = File(p.join(exportDir.path, 'budget_lite_backup.db'));
    await file.copy(exportFile.path);
    return exportFile.path;
  }

  /// Export all database entities to a structured JSON file.
  Future<String> exportJsonBackup() async {
    final db = ref.read(databaseProvider);
    final accounts = await db.select(db.accounts).get();
    final categories = await db.select(db.categories).get();
    final transactions = await db.select(db.transactions).get();
    final budgets = await db.select(db.budgets).get();
    final goals = await db.select(db.goals).get();
    final income = await db.select(db.monthlyIncome).get();
    final settings = await db.select(db.appSettings).get();

    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'accounts': accounts.map((a) => {'id': a.id, 'name': a.name, 'balance': a.balance, 'currency': a.currency}).toList(),
      'categories': categories.map((c) => {'id': c.id, 'name': c.name, 'icon': c.icon, 'color': c.color, 'type': c.type}).toList(),
      'transactions': transactions.map((t) => {
        'id': t.id,
        'amount': t.amount,
        'categoryId': t.categoryId,
        'accountId': t.accountId,
        'note': t.note,
        'payee': t.payee,
        'date': t.date.toIso8601String(),
        'paymentMethod': t.paymentMethod,
        'isRecurring': t.isRecurring,
        'isRecurringInstance': t.isRecurringInstance,
        'recurringInterval': t.recurringInterval,
        'recurringEndDate': t.recurringEndDate?.toIso8601String(),
        'receiptImagePath': t.receiptImagePath,
        'createdAt': t.createdAt.toIso8601String(),
      }).toList(),
      'budgets': budgets.map((b) => {'id': b.id, 'categoryId': b.categoryId, 'month': b.month, 'allocatedAmount': b.allocatedAmount, 'rollover': b.rollover}).toList(),
      'goals': goals.map((g) => {'id': g.id, 'name': g.name, 'targetAmount': g.targetAmount, 'currentAmount': g.currentAmount, 'targetDate': g.targetDate.toIso8601String(), 'color': g.color, 'icon': g.icon, 'createdAt': g.createdAt.toIso8601String()}).toList(),
      'monthlyIncome': income.map((i) => {'id': i.id, 'month': i.month, 'amount': i.amount, 'createdAt': i.createdAt.toIso8601String()}).toList(),
      'settings': settings.map((s) => {'key': s.key, 'value': s.value}).toList(),
    };

    final tempDir = await getTemporaryDirectory();
    final file = File(p.join(tempDir.path, 'budget_lite_backup_${DateTime.now().millisecondsSinceEpoch}.json'));
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file.path;
  }

  /// Import database entities from a JSON backup file.
  Future<int> importJsonBackup(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('Backup file not found');
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;

    final db = ref.read(databaseProvider);
    int importedCount = 0;

    Future<void> processList(String key, Future<void> Function(Map<String, dynamic> m) insert) async {
      final list = json[key];
      if (list is List) {
        for (final item in list) {
          if (item is Map<String, dynamic>) await insert(item);
        }
      }
    }

    await db.transaction(() async {
      await processList('accounts', (m) async => db.into(db.accounts).insertOnConflictUpdate(AccountsCompanion.insert(
        id: m['id'] as String,
        name: m['name'] as String,
        balance: Value((m['balance'] as num).toDouble()),
        currency: Value(m['currency'] as String? ?? 'INR'),
      )));

      await processList('categories', (m) async => db.into(db.categories).insertOnConflictUpdate(CategoriesCompanion.insert(
        id: m['id'] as String,
        name: m['name'] as String,
        icon: Value(m['icon'] as String? ?? 'category'),
        color: Value(m['color'] as int? ?? 0xFF0D7377),
        type: Value(m['type'] as String? ?? 'expense'),
      )));

      await processList('transactions', (m) async {
        await db.into(db.transactions).insertOnConflictUpdate(TransactionsCompanion.insert(
          id: m['id'] as String,
          amount: (m['amount'] as num).toDouble(),
          categoryId: m['categoryId'] as String,
          accountId: m['accountId'] as String,
          note: Value(m['note'] as String?),
          payee: Value(m['payee'] as String?),
          date: DateTime.parse(m['date'] as String),
          paymentMethod: Value(m['paymentMethod'] as String? ?? 'cash'),
          isRecurring: Value(m['isRecurring'] as bool? ?? false),
          isRecurringInstance: Value(m['isRecurringInstance'] as bool? ?? false),
          recurringInterval: Value(m['recurringInterval'] as String?),
          recurringEndDate: Value(m['recurringEndDate'] != null ? DateTime.parse(m['recurringEndDate'] as String) : null),
          receiptImagePath: Value(m['receiptImagePath'] as String?),
          createdAt: Value(m['createdAt'] != null ? DateTime.parse(m['createdAt'] as String) : DateTime.now()),
        ));
        importedCount++;
      });

      await processList('budgets', (m) async => db.into(db.budgets).insertOnConflictUpdate(BudgetsCompanion.insert(
        id: m['id'] as String,
        categoryId: m['categoryId'] as String,
        month: m['month'] as String,
        allocatedAmount: (m['allocatedAmount'] as num).toDouble(),
        rollover: Value(m['rollover'] as bool? ?? false),
      )));

      await processList('goals', (m) async => db.into(db.goals).insertOnConflictUpdate(GoalsCompanion.insert(
        id: m['id'] as String,
        name: m['name'] as String,
        targetAmount: (m['targetAmount'] as num).toDouble(),
        currentAmount: Value((m['currentAmount'] as num? ?? 0).toDouble()),
        targetDate: DateTime.parse(m['targetDate'] as String),
        color: Value(m['color'] as int? ?? 0xFF14B8A6),
        icon: Value(m['icon'] as String? ?? 'flag'),
        createdAt: Value(m['createdAt'] != null ? DateTime.parse(m['createdAt'] as String) : DateTime.now()),
      )));

      await processList('settings', (m) async => db.into(db.appSettings).insertOnConflictUpdate(AppSettingsCompanion.insert(
        key: m['key'] as String,
        value: m['value'] as String,
      )));
    });

    ref.invalidate(databaseProvider);
    return importedCount;
  }

  Future<void> importDatabase(String filePath) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final source = File(filePath);
    if (!await source.exists()) throw Exception('Backup file not found');

    final dest = File(p.join(dbFolder.path, 'budget_lite.db'));

    // Close the live connection BEFORE overwriting the file — copying over an
    // open SQLite database (with possibly unflushed WAL/SHM pages) risks
    // corruption. Stale sidecar files must also go.
    final oldDb = ref.read(databaseProvider);
    await oldDb.close();
    for (final suffix in ['-wal', '-shm']) {
      final sidecar = File('${dest.path}$suffix');
      if (await sidecar.exists()) {
        try {
          await sidecar.delete();
        } catch (_) {}
      }
    }

    await source.copy(dest.path);
    ref.invalidate(databaseProvider);
  }
  /// Mark a budget threshold as notified for a category (prevents repeated alerts).
  Future<void> setBudgetNotified(String categoryId, String level) async {
    final stored = await getSetting('budget_notified');
    final map = stored != null && stored.isNotEmpty
        ? AccessibilityUtils.decodeJson(stored)
        : <String, dynamic>{};
    map[categoryId] = level;
    await setSetting('budget_notified', AccessibilityUtils.encodeJson(map));
  }

  Future<bool> wasBudgetNotified(String categoryId, String level) async {
    final stored = await getSetting('budget_notified');
    if (stored == null || stored.isEmpty) return false;
    try {
      final map = AccessibilityUtils.decodeJson(stored);
      return map[categoryId] == level;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetBudgetNotified(String categoryId) async {
    final stored = await getSetting('budget_notified');
    if (stored == null || stored.isEmpty) return;
    try {
      final map = AccessibilityUtils.decodeJson(stored);
      map.remove(categoryId);
      await setSetting('budget_notified', AccessibilityUtils.encodeJson(map));
    } catch (_) {}
  }
  Future<bool> getBalanceHidden() async {
    final val = await getSetting('balance_hidden');
    return val == 'true';
  }

  Future<void> setBalanceHidden(bool value) async {
    await setSetting('balance_hidden', value.toString());
    ref.invalidate(balanceHiddenProvider);
  }

  Future<void> setSmsAutoNoteEnabled(bool value) async {
    await setSetting('sms_auto_note_enabled', value.toString());
    ref.invalidate(smsAutoNoteEnabledProvider);
  }

  Future<int> getAutoLockDuration() async {
    final val = await getSetting('auto_lock_minutes');
    return int.tryParse(val ?? '') ?? 1;
  }

  Future<void> setAutoLockDuration(int minutes) async {
    await setSetting('auto_lock_minutes', minutes.toString());
    ref.invalidate(autoLockDurationProvider);
  }

  Future<int?> getAccentColor() async {
    final val = await getSetting('accent_color');
    return val != null ? int.tryParse(val) : null;
  }

  Future<void> setAccentColor(int colorValue) async {
    await setSetting('accent_color', colorValue.toString());
    ref.invalidate(accentColorProvider);
  }

  Future<bool> getBudgetModuleEnabled() async {
    final val = await getSetting('budget_module_enabled');
    return val != 'false';
  }

  Future<void> setBudgetModuleEnabled(bool value) async {
    await setSetting('budget_module_enabled', value.toString());
    ref.invalidate(budgetModuleEnabledProvider);
  }

  // ── Subscription Review Tracking ──
  /// Mark a subscription transaction as reviewed/used by the user.
  /// Stores a set of reviewed transaction IDs in AppSettings.
  Future<void> markSubscriptionReviewed(String transactionId) async {
    final stored = await getSetting('subscription_reviewed');
    Set<String> set;
    if (stored != null && stored.isNotEmpty) {
      try {
        set = Set<String>.from(const JsonDecoder().convert(stored) as List);
      } catch (_) {
        set = <String>{};
      }
    } else {
      set = <String>{};
    }
    set.add(transactionId);
    await setSetting('subscription_reviewed', jsonEncode(set.toList()));
  }

  Future<bool> isSubscriptionReviewed(String transactionId) async {
    final stored = await getSetting('subscription_reviewed');
    if (stored == null || stored.isEmpty) return false;
    try {
      final set = Set<String>.from(const JsonDecoder().convert(stored) as List);
      return set.contains(transactionId);
    } catch (_) {
      return false;
    }
  }

  Future<void> resetSubscriptionReview(String transactionId) async {
    final stored = await getSetting('subscription_reviewed');
    if (stored == null || stored.isEmpty) return;
    try {
      final set = Set<String>.from(const JsonDecoder().convert(stored) as List);
      set.remove(transactionId);
      await setSetting('subscription_reviewed', jsonEncode(set.toList()));
    } catch (_) {}
  }
}

final settingsNotifierProvider =
    StateNotifierProvider<SettingsNotifier, AsyncValue<void>>((ref) {
  return SettingsNotifier(ref);
});

final darkModeProvider = FutureProvider<bool>((ref) async {
  final settings = ref.read(settingsNotifierProvider.notifier);
  return settings.getDarkMode();
});

final themeModeProvider = FutureProvider<ThemeModeOption>((ref) async {
  final settings = ref.read(settingsNotifierProvider.notifier);
  return settings.getThemeMode();
});

final biometricLockEnabledProvider = FutureProvider<bool>((ref) async {
  final settings = ref.read(settingsNotifierProvider.notifier);
  return settings.getBiometricLock();
});

final smsParsingEnabledProvider = FutureProvider<bool>((ref) async {
  final settings = ref.read(settingsNotifierProvider.notifier);
  return settings.getSmsParsing();
});

final balanceHiddenProvider = FutureProvider<bool>((ref) async {
  final settings = ref.read(settingsNotifierProvider.notifier);
  return settings.getBalanceHidden();
});

final autoLockDurationProvider = FutureProvider<int>((ref) async {
  final settings = ref.read(settingsNotifierProvider.notifier);
  return settings.getAutoLockDuration();
});

final accentColorProvider = FutureProvider<int?>((ref) async {
  final settings = ref.read(settingsNotifierProvider.notifier);
  return settings.getAccentColor();
});

final budgetModuleEnabledProvider = FutureProvider<bool>((ref) async {
  final settings = ref.read(settingsNotifierProvider.notifier);
  return settings.getBudgetModuleEnabled();
});

final smsAutoNoteEnabledProvider = FutureProvider<bool>((ref) async {
  final settings = ref.read(settingsNotifierProvider.notifier);
  final val = await settings.getSetting('sms_auto_note_enabled');
  return val != 'false';
});

/// Provider that loads/saves auto-categorization rules from AppSettings.
/// Falls back to [CategorizationRule.defaults] on first load.
final autoCategorizationRulesProvider =
    NotifierProvider<AutoCategorizationRulesNotifier, List<CategorizationRule>>(
  AutoCategorizationRulesNotifier.new,
);

class AutoCategorizationRulesNotifier extends Notifier<List<CategorizationRule>> {
  final Completer<void> _loaded = Completer<void>();

  @override
  List<CategorizationRule> build() {
    _loadRules();
    return CategorizationRule.defaults();
  }

  Future<void> _loadRules() async {
    try {
      final settings = ref.read(settingsNotifierProvider.notifier);
      final stored = await settings.getSetting('auto_category_rules');
      if (stored != null && stored.isNotEmpty) {
        try {
          final list = (const JsonDecoder().convert(stored) as List)
              .map((e) => CategorizationRule.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList();
          if (list.isNotEmpty) {
            state = list;
          }
        } catch (_) {}
      }
    } finally {
      if (!_loaded.isCompleted) _loaded.complete();
    }
  }

  Future<void> _persist() async {
    await _loaded.future;
    final settings = ref.read(settingsNotifierProvider.notifier);
    final jsonStr = const JsonEncoder().convert(state.map((r) => r.toJson()).toList());
    await settings.setSetting('auto_category_rules', jsonStr);
  }

  Future<void> setRules(List<CategorizationRule> rules) async {
    // Wait for the initial load first, otherwise a late-arriving _loadRules()
    // could clobber freshly saved rules with stale storage contents.
    await _loaded.future;
    state = rules;
    await _persist();
  }

  /// Detect a category ID from a note string using the current rules.
  String? detectCategory(String note) {
    for (final rule in state) {
      if (rule.toRegExp().hasMatch(note)) {
        return rule.categoryId;
      }
    }
    return null;
  }
}
