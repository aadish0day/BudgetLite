import 'package:budget_lite/core/services/firestore_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CloudSyncResult Tests', () {
    test('Constructs with defaults', () {
      const result = CloudSyncResult(
        success: true,
        message: 'Backup completed successfully',
      );

      expect(result.success, isTrue);
      expect(result.message, 'Backup completed successfully');
      expect(result.uploadedCount, 0);
      expect(result.downloadedCount, 0);
      expect(result.timestamp, isNull);
    });

    test('Constructs with custom counts and timestamp', () {
      final now = DateTime.now();
      final result = CloudSyncResult(
        success: true,
        message: 'Restored 15 items',
        downloadedCount: 15,
        timestamp: now,
      );

      expect(result.success, isTrue);
      expect(result.uploadedCount, 0);
      expect(result.downloadedCount, 15);
      expect(result.timestamp, now);
    });

    test('Constructs error result', () {
      const result = CloudSyncResult(
        success: false,
        message: 'Network error',
      );

      expect(result.success, isFalse);
      expect(result.message, 'Network error');
    });
  });

  group('CloudSyncStatus Tests', () {
    test('Constructs properly', () {
      final now = DateTime.now();
      final status = CloudSyncStatus(
        syncId: 'SYNC-1234',
        lastSynced: now,
        totalBackedUpItems: 42,
      );

      expect(status.syncId, 'SYNC-1234');
      expect(status.lastSynced, now);
      expect(status.totalBackedUpItems, 42);
    });
  });
}
