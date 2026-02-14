import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/utils/logger.dart';
import '../../core/errors/failures.dart';

class EncryptionService {
  static const _storage = FlutterSecureStorage();
  static const String _keyName = 'encryption_key';

  Future<Encrypted> encryptData(Uint8List data) async {
    try {
      // Validate input data
      if (data.isEmpty) {
        throw EncryptionFailure('Cannot encrypt empty data');
      }

      AppLogger.i('Encrypting ${data.length} bytes of data');

      final key = await _getOrCreateKey();
      final iv = IV.fromSecureRandom(16);
      final encrypter = Encrypter(AES(key));

      AppLogger.i('Key and IV generated, starting encryption...');

      final encrypted = encrypter.encryptBytes(data, iv: iv);
      
      AppLogger.i('Encryption complete, encrypted size: ${encrypted.bytes.length} bytes');

      // Prepend IV to encrypted data for decryption
      final result = Uint8List(iv.bytes.length + encrypted.bytes.length);
      result.setRange(0, iv.bytes.length, iv.bytes);
      result.setRange(iv.bytes.length, result.length, encrypted.bytes);

      AppLogger.i('IV prepended, final encrypted size: ${result.length} bytes');

      return Encrypted(result);
    } catch (e) {
      AppLogger.e('Encryption failed', e);
      if (e is EncryptionFailure) {
        rethrow;
      }
      throw EncryptionFailure('Failed to encrypt data: ${e.toString()}');
    }
  }

  Future<Uint8List> decryptData(Encrypted encryptedData) async {
    try {
      final key = await _getOrCreateKey();
      
      // Extract IV from first 16 bytes
      final iv = IV(encryptedData.bytes.sublist(0, 16));
      final encryptedBytes = encryptedData.bytes.sublist(16);
      final encrypted = Encrypted(encryptedBytes);
      
      final encrypter = Encrypter(AES(key));
      return Uint8List.fromList(encrypter.decryptBytes(encrypted, iv: iv));
    } catch (e) {
      AppLogger.e('Decryption failed', e);
      throw EncryptionFailure('Failed to decrypt data: ${e.toString()}');
    }
  }

  Future<Key> _getOrCreateKey() async {
    try {
      final keyString = await _storage.read(key: _keyName);
      
      if (keyString != null) {
        return Key.fromBase64(keyString);
      }

      // Generate new key
      final key = Key.fromSecureRandom(32);
      await _storage.write(
        key: _keyName,
        value: key.base64,
      );

      return key;
    } catch (e) {
      AppLogger.e('Key retrieval failed', e);
      throw EncryptionFailure('Failed to get encryption key: ${e.toString()}');
    }
  }

  Future<void> clearKey() async {
    try {
      await _storage.delete(key: _keyName);
    } catch (e) {
      AppLogger.e('Key deletion failed', e);
    }
  }
}
