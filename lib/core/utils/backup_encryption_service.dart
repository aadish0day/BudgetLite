import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';

class InvalidBackupPasswordException implements Exception {
  const InvalidBackupPasswordException([this.message = 'Incorrect password or corrupted backup file.']);

  final String message;

  @override
  String toString() => message;
}

class DecryptedBackupResult {
  const DecryptedBackupResult({
    required this.data,
    required this.type,
    required this.exportedAt,
  });

  final Uint8List data;
  final String type; // 'json' or 'sqlite'
  final DateTime exportedAt;
}

class BackupEncryptionService {
  static const String containerFormat = 'budgetlite_encrypted_backup';
  static const int currentFormatVersion = 1;
  static const int pbkdf2Iterations = 100000;
  static const int keyLengthBytes = 32; // AES-256
  static const int saltLengthBytes = 16;
  static const int ivLengthBytes = 16;

  /// Derives a 256-bit AES key using PBKDF2 with HMAC-SHA256.
  static Uint8List deriveKey(String password, Uint8List salt, {int iterations = pbkdf2Iterations}) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, keyLengthBytes));
    final passwordBytes = Uint8List.fromList(utf8.encode(password));
    return pbkdf2.process(passwordBytes);
  }

  /// Generates cryptographically secure random bytes.
  static Uint8List generateRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (int i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// Encrypts raw data bytes with AES-256-CBC and PBKDF2 key derivation.
  static String encrypt({
    required Uint8List payloadBytes,
    required String password,
    required String type, // 'json' or 'sqlite'
  }) {
    if (password.trim().isEmpty) {
      throw ArgumentError('Password cannot be empty.');
    }

    final salt = generateRandomBytes(saltLengthBytes);
    final ivBytes = generateRandomBytes(ivLengthBytes);

    final keyBytes = deriveKey(password, salt);
    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encryptBytes(payloadBytes, iv: iv);

    // Compute checksum (SHA-256) of raw payload to verify decryption integrity
    final checksum = crypto.sha256.convert(payloadBytes).toString();

    final container = <String, dynamic>{
      'format': containerFormat,
      'version': currentFormatVersion,
      'type': type,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'iterations': pbkdf2Iterations,
      'salt': base64Encode(salt),
      'iv': base64Encode(ivBytes),
      'ciphertext': encrypted.base64,
      'checksum': checksum,
      'createdAt': DateTime.now().toIso8601String(),
    };

    return const JsonEncoder.withIndent('  ').convert(container);
  }

  /// Checks if a given string or file header matches BudgetLite encrypted backup format.
  static bool isEncryptedBackup(String content) {
    try {
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded['format'] == containerFormat;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Decrypts an encrypted container string with the provided password.
  static DecryptedBackupResult decrypt({
    required String containerJson,
    required String password,
  }) {
    final Map<String, dynamic> container;
    try {
      container = jsonDecode(containerJson) as Map<String, dynamic>;
    } catch (_) {
      throw const InvalidBackupPasswordException('Invalid backup archive format.');
    }

    if (container['format'] != containerFormat) {
      throw const InvalidBackupPasswordException('Unrecognized backup format.');
    }

    final salt = base64Decode(container['salt'] as String);
    final ivBytes = base64Decode(container['iv'] as String);
    final ciphertextBase64 = container['ciphertext'] as String;
    final expectedChecksum = container['checksum'] as String;
    final iterations = (container['iterations'] as int?) ?? pbkdf2Iterations;
    final type = (container['type'] as String?) ?? 'json';
    final exportedAt = container['createdAt'] != null
        ? DateTime.tryParse(container['createdAt'] as String) ?? DateTime.now()
        : DateTime.now();

    final keyBytes = deriveKey(password, salt, iterations: iterations);
    final key = enc.Key(keyBytes);
    final iv = enc.IV(ivBytes);

    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));

    final Uint8List decryptedBytes;
    try {
      final decryptedList = encrypter.decryptBytes(enc.Encrypted.fromBase64(ciphertextBase64), iv: iv);
      decryptedBytes = Uint8List.fromList(decryptedList);
    } catch (_) {
      throw const InvalidBackupPasswordException();
    }

    // Verify payload checksum
    final actualChecksum = crypto.sha256.convert(decryptedBytes).toString();
    if (actualChecksum != expectedChecksum) {
      throw const InvalidBackupPasswordException('Data integrity checksum mismatch. File may be corrupted.');
    }

    return DecryptedBackupResult(
      data: decryptedBytes,
      type: type,
      exportedAt: exportedAt,
    );
  }
}
