import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/budget_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../database/database.dart';

class CloudSyncResult {
  const CloudSyncResult({
    required this.success,
    required this.message,
    this.uploadedCount = 0,
    this.downloadedCount = 0,
    this.timestamp,
  });

  final bool success;
  final String message;
  final int uploadedCount;
  final int downloadedCount;
  final DateTime? timestamp;
}

class CloudSyncStatus {
  const CloudSyncStatus({
    required this.syncId,
    required this.lastSynced,
    required this.totalBackedUpItems,
  });

  final String syncId;
  final DateTime? lastSynced;
  final int totalBackedUpItems;
}

final firestoreSyncServiceProvider = Provider<FirestoreSyncService>((ref) {
  return FirestoreSyncService(ref);
});

class FirestoreSyncService {
  FirestoreSyncService(this.ref);

  final Ref ref;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Retrieves or generates a persistent device/cloud Sync ID.
  Future<String> getSyncId() async {
    final settings = ref.read(settingsNotifierProvider.notifier);
    final stored = await settings.getSetting('cloud_sync_id');
    if (stored != null && stored.trim().isNotEmpty) {
      return stored.trim();
    }
    // Default clean identifier linked to pre-seeded cloud profile
    const newId = 'demo_user';
    await settings.setSetting('cloud_sync_id', newId);
    return newId;
  }

  /// Manually link or change the Sync ID (e.g. to restore backup from another device)
  Future<void> setSyncId(String newId) async {
    final settings = ref.read(settingsNotifierProvider.notifier);
    await settings.setSetting('cloud_sync_id', newId.trim());
  }

  /// Get current sync status from local AppSettings
  Future<CloudSyncStatus> getStatus() async {
    final settings = ref.read(settingsNotifierProvider.notifier);
    final syncId = await getSyncId();
    final lastTimeStr = await settings.getSetting('cloud_last_synced');
    final countStr = await settings.getSetting('cloud_last_synced_count');

    return CloudSyncStatus(
      syncId: syncId,
      lastSynced: lastTimeStr != null ? DateTime.tryParse(lastTimeStr) : null,
      totalBackedUpItems: int.tryParse(countStr ?? '0') ?? 0,
    );
  }

  /// Backs up all local Drift SQLite data into Cloud Firestore.
  /// Structure: users/{syncId}/...
  Future<CloudSyncResult> backupToCloud() async {
    try {
      final db = ref.read(databaseProvider);
      final syncId = await getSyncId();
      final userDoc = _firestore.collection('users').doc(syncId);

      final accounts = await db.select(db.accounts).get();
      final categories = await db.select(db.categories).get();
      final transactions = await db.select(db.transactions).get();
      final budgets = await db.select(db.budgets).get();
      final goals = await db.select(db.goals).get();

      final now = DateTime.now();
      int totalUploaded = 0;

      // Firestore batches support up to 500 operations per batch
      WriteBatch batch = _firestore.batch();
      int batchCount = 0;

      Future<void> commitBatchIfNeeded() async {
        if (batchCount >= 450) {
          await batch.commit();
          batch = _firestore.batch();
          batchCount = 0;
        }
      }

      // 1. Accounts
      for (final a in accounts) {
        final refDoc = userDoc.collection('accounts').doc(a.id);
        batch.set(refDoc, {
          'id': a.id,
          'name': a.name,
          'balance': a.balance,
          'currency': a.currency,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        batchCount++;
        totalUploaded++;
        await commitBatchIfNeeded();
      }

      // 2. Categories
      for (final c in categories) {
        final refDoc = userDoc.collection('categories').doc(c.id);
        batch.set(refDoc, {
          'id': c.id,
          'name': c.name,
          'icon': c.icon,
          'color': c.color,
          'type': c.type,
          'sortOrder': c.sortOrder,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        batchCount++;
        totalUploaded++;
        await commitBatchIfNeeded();
      }

      // 3. Transactions
      for (final t in transactions) {
        final refDoc = userDoc.collection('transactions').doc(t.id);
        batch.set(refDoc, {
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
          'createdAt': t.createdAt.toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        batchCount++;
        totalUploaded++;
        await commitBatchIfNeeded();
      }

      // 4. Budgets
      for (final b in budgets) {
        final refDoc = userDoc.collection('budgets').doc(b.id);
        batch.set(refDoc, {
          'id': b.id,
          'categoryId': b.categoryId,
          'month': b.month,
          'allocatedAmount': b.allocatedAmount,
          'rollover': b.rollover,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        batchCount++;
        totalUploaded++;
        await commitBatchIfNeeded();
      }

      // 5. Goals
      for (final g in goals) {
        final refDoc = userDoc.collection('goals').doc(g.id);
        batch.set(refDoc, {
          'id': g.id,
          'name': g.name,
          'targetAmount': g.targetAmount,
          'currentAmount': g.currentAmount,
          'targetDate': g.targetDate.toIso8601String(),
          'color': g.color,
          'icon': g.icon,
          'createdAt': g.createdAt.toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        batchCount++;
        totalUploaded++;
        await commitBatchIfNeeded();
      }

      // 6. User Meta Summary
      batch.set(userDoc, {
        'lastSynced': FieldValue.serverTimestamp(),
        'appVersion': '1.0.0',
        'itemCount': totalUploaded,
        'transactionCount': transactions.length,
        'budgetCount': budgets.length,
        'goalCount': goals.length,
      });
      batchCount++;

      // Commit remaining batch
      if (batchCount > 0) {
        await batch.commit();
      }

      // Update local settings
      final settings = ref.read(settingsNotifierProvider.notifier);
      await settings.setSetting('cloud_last_synced', now.toIso8601String());
      await settings.setSetting('cloud_last_synced_count', '$totalUploaded');

      return CloudSyncResult(
        success: true,
        message: 'Successfully backed up $totalUploaded items to Cloud Firestore!',
        uploadedCount: totalUploaded,
        timestamp: now,
      );
    } catch (e) {
      return CloudSyncResult(
        success: false,
        message: 'Cloud backup failed: $e',
      );
    }
  }

  /// Restores all data from Cloud Firestore into local Drift SQLite.
  Future<CloudSyncResult> restoreFromCloud() async {
    try {
      final db = ref.read(databaseProvider);
      final syncId = await getSyncId();
      final userDoc = _firestore.collection('users').doc(syncId);

      // Verify backup exists
      final metaSnap = await userDoc.get();
      if (!metaSnap.exists) {
        return const CloudSyncResult(
          success: false,
          message: 'No cloud backup found for this Sync ID. Backup first or check your Sync ID.',
        );
      }

      final accountsSnap = await userDoc.collection('accounts').get();
      final categoriesSnap = await userDoc.collection('categories').get();
      final transactionsSnap = await userDoc.collection('transactions').get();
      final budgetsSnap = await userDoc.collection('budgets').get();
      final goalsSnap = await userDoc.collection('goals').get();

      int downloadedCount = 0;

      await db.transaction(() async {
        // Accounts
        for (final doc in accountsSnap.docs) {
          final data = doc.data();
          await db.into(db.accounts).insertOnConflictUpdate(
                AccountsCompanion.insert(
                  id: doc.id,
                  name: data['name'] as String? ?? 'Account',
                  balance: Value((data['balance'] as num?)?.toDouble() ?? 0.0),
                  currency: Value(data['currency'] as String? ?? 'INR'),
                ),
              );
          downloadedCount++;
        }

        // Categories
        for (final doc in categoriesSnap.docs) {
          final data = doc.data();
          await db.into(db.categories).insertOnConflictUpdate(
                CategoriesCompanion.insert(
                  id: doc.id,
                  name: data['name'] as String? ?? 'Category',
                  icon: Value(data['icon'] as String? ?? 'category'),
                  color: Value((data['color'] as num?)?.toInt() ?? 0xFF0D7377),
                  type: Value(data['type'] as String? ?? 'expense'),
                  sortOrder: Value((data['sortOrder'] as num?)?.toInt() ?? 0),
                ),
              );
          downloadedCount++;
        }

        // Transactions
        for (final doc in transactionsSnap.docs) {
          final data = doc.data();
          final dateStr = data['date'] as String?;
          final createdStr = data['createdAt'] as String?;
          final endStr = data['recurringEndDate'] as String?;

          await db.into(db.transactions).insertOnConflictUpdate(
                TransactionsCompanion.insert(
                  id: doc.id,
                  amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
                  categoryId: data['categoryId'] as String? ?? 'other',
                  accountId: data['accountId'] as String? ?? 'default',
                  note: Value(data['note'] as String?),
                  payee: Value(data['payee'] as String?),
                  date: dateStr != null ? DateTime.parse(dateStr) : DateTime.now(),
                  paymentMethod: Value(data['paymentMethod'] as String? ?? 'cash'),
                  isRecurring: Value(data['isRecurring'] as bool? ?? false),
                  isRecurringInstance: Value(data['isRecurringInstance'] as bool? ?? false),
                  recurringInterval: Value(data['recurringInterval'] as String?),
                  recurringEndDate: Value(endStr != null ? DateTime.tryParse(endStr) : null),
                  createdAt: Value(createdStr != null ? DateTime.parse(createdStr) : DateTime.now()),
                ),
              );
          downloadedCount++;
        }

        // Budgets
        for (final doc in budgetsSnap.docs) {
          final data = doc.data();
          await db.into(db.budgets).insertOnConflictUpdate(
                BudgetsCompanion.insert(
                  id: doc.id,
                  categoryId: data['categoryId'] as String? ?? 'other',
                  month: data['month'] as String? ?? '2026-01',
                  allocatedAmount: (data['allocatedAmount'] as num?)?.toDouble() ?? 0.0,
                  rollover: Value(data['rollover'] as bool? ?? false),
                ),
              );
          downloadedCount++;
        }

        // Goals
        for (final doc in goalsSnap.docs) {
          final data = doc.data();
          final targetStr = data['targetDate'] as String?;
          final createdStr = data['createdAt'] as String?;

          await db.into(db.goals).insertOnConflictUpdate(
                GoalsCompanion.insert(
                  id: doc.id,
                  name: data['name'] as String? ?? 'Goal',
                  targetAmount: (data['targetAmount'] as num?)?.toDouble() ?? 0.0,
                  currentAmount: Value((data['currentAmount'] as num?)?.toDouble() ?? 0.0),
                  targetDate: targetStr != null ? DateTime.parse(targetStr) : DateTime.now(),
                  color: Value((data['color'] as num?)?.toInt() ?? 0xFF14B8A6),
                  icon: Value(data['icon'] as String? ?? 'flag'),
                  createdAt: Value(createdStr != null ? DateTime.parse(createdStr) : DateTime.now()),
                ),
              );
          downloadedCount++;
        }
      });

      // Invalidate state so all screens immediately refresh
      ref.invalidate(databaseProvider);
      ref.invalidate(categoriesProvider);
      ref.invalidate(accountsProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(thisMonthTransactionsProvider);
      ref.invalidate(totalSpentThisMonthProvider);
      ref.invalidate(totalIncomeThisMonthProvider);
      ref.invalidate(budgetsProvider);
      ref.invalidate(thisMonthBudgetsProvider);
      ref.invalidate(goalsProvider);

      final now = DateTime.now();
      final settings = ref.read(settingsNotifierProvider.notifier);
      await settings.setSetting('cloud_last_synced', now.toIso8601String());

      return CloudSyncResult(
        success: true,
        message: 'Successfully restored $downloadedCount items from Cloud Firestore!',
        downloadedCount: downloadedCount,
        timestamp: now,
      );
    } catch (e) {
      return CloudSyncResult(
        success: false,
        message: 'Cloud restore failed: $e',
      );
    }
  }
}
