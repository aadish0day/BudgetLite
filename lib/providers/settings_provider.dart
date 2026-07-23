import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../core/database/database.dart';
import 'database_provider.dart';

final settingsProvider = FutureProvider.family<String?, String>((ref, key) async {
  final db = ref.read(databaseProvider);
  final rows = await (db.select(db.appSettings)..where((t) => t.key.equals(key))).get();
  return rows.isNotEmpty ? rows.first.value : null;
});

class SettingsNotifier extends StateNotifier<AsyncValue<void>> {
  SettingsNotifier(this.ref) : super(const AsyncData(null));
  final Ref ref;

  Future<void> setSetting(String key, String value) async {
    final db = ref.read(databaseProvider);
    final existing = await (db.select(db.appSettings)..where((t) => t.key.equals(key))).get();

    if (existing.isNotEmpty) {
      await (db.update(db.appSettings)..where((t) => t.key.equals(key)))
          .write(AppSettingsCompanion(value: Value('')));
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

  Future<String> getCurrency() async {
    return (await getSetting('currency')) ?? 'INR';
  }

  Future<void> setCurrency(String value) async {
    await setSetting('currency', value);
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

  Future<void> importDatabase(String filePath) async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final source = File(filePath);
    if (!await source.exists()) throw Exception('Backup file not found');

    final dest = File(p.join(dbFolder.path, 'budget_lite.db'));
    await source.copy(dest.path);
    ref.invalidate(databaseProvider);
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

final biometricLockEnabledProvider = FutureProvider<bool>((ref) async {
  final settings = ref.read(settingsNotifierProvider.notifier);
  return settings.getBiometricLock();
});

final smsParsingEnabledProvider = FutureProvider<bool>((ref) async {
  final settings = ref.read(settingsNotifierProvider.notifier);
  return settings.getSmsParsing();
});
