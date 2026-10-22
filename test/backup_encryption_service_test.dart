import 'dart:convert';
import 'dart:typed_data';
import 'package:budget_lite/core/utils/backup_encryption_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackupEncryptionService Tests', () {
    const testPassword = 'SuperSecretPassword123!';
    final jsonPayload = utf8.encode(jsonEncode({
      'version': 1,
      'accounts': [{'id': 'default', 'name': 'Main Account', 'balance': 5400.0}],
      'categories': [{'id': 'cat_food', 'name': 'Food'}],
      'transactions': [{'id': 'tx_1', 'amount': 150.0, 'note': 'Lunch'}],
    }));

    test('encrypts and successfully decrypts JSON payload with correct password', () {
      final encryptedContainer = BackupEncryptionService.encrypt(
        payloadBytes: Uint8List.fromList(jsonPayload),
        password: testPassword,
        type: 'json',
      );

      expect(BackupEncryptionService.isEncryptedBackup(encryptedContainer), isTrue);

      final result = BackupEncryptionService.decrypt(
        containerJson: encryptedContainer,
        password: testPassword,
      );

      expect(result.type, equals('json'));
      final decodedJson = jsonDecode(utf8.decode(result.data)) as Map<String, dynamic>;
      expect(decodedJson['version'], equals(1));
      expect(decodedJson['transactions'], isNotEmpty);
      expect(decodedJson['transactions'][0]['id'], equals('tx_1'));
    });

    test('encrypts and decrypts raw binary SQLite bytes', () {
      final binarySqliteHeader = Uint8List.fromList([
        0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66, 0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
        1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
      ]);

      final encryptedContainer = BackupEncryptionService.encrypt(
        payloadBytes: binarySqliteHeader,
        password: testPassword,
        type: 'sqlite',
      );

      final result = BackupEncryptionService.decrypt(
        containerJson: encryptedContainer,
        password: testPassword,
      );

      expect(result.type, equals('sqlite'));
      expect(result.data, equals(binarySqliteHeader));
    });

    test('throws InvalidBackupPasswordException when password is wrong', () {
      final encryptedContainer = BackupEncryptionService.encrypt(
        payloadBytes: Uint8List.fromList(jsonPayload),
        password: testPassword,
        type: 'json',
      );

      expect(
        () => BackupEncryptionService.decrypt(
          containerJson: encryptedContainer,
          password: 'WrongPassword!',
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );
    });

    test('throws InvalidBackupPasswordException when container is tampered with', () {
      final encryptedContainer = BackupEncryptionService.encrypt(
        payloadBytes: Uint8List.fromList(jsonPayload),
        password: testPassword,
        type: 'json',
      );

      final decoded = jsonDecode(encryptedContainer) as Map<String, dynamic>;
      // Tamper with checksum
      decoded['checksum'] = '0000000000000000000000000000000000000000000000000000000000000000';
      final tampered = jsonEncode(decoded);

      expect(
        () => BackupEncryptionService.decrypt(
          containerJson: tampered,
          password: testPassword,
        ),
        throwsA(isA<InvalidBackupPasswordException>()),
      );
    });

    test('throws ArgumentError on empty password', () {
      expect(
        () => BackupEncryptionService.encrypt(
          payloadBytes: Uint8List.fromList(jsonPayload),
          password: '   ',
          type: 'json',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
