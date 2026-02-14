import 'dart:io';
import 'package:encrypt/encrypt.dart' show Encrypted;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../core/utils/logger.dart';
import '../../core/errors/failures.dart';
import '../../core/constants/app_constants.dart';
import '../encryption/encryption_service.dart';

class LocalStorageService {
  final EncryptionService _encryptionService = EncryptionService();
  Directory? _recordingsDirectory;

  Future<Directory> initialize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _recordingsDirectory = Directory(
        path.join(appDir.path, AppConstants.recordingsDirectory),
      );

      if (!await _recordingsDirectory!.exists()) {
        await _recordingsDirectory!.create(recursive: true);
      }

      AppLogger.i('Local storage initialized: ${_recordingsDirectory!.path}');
      return _recordingsDirectory!;
    } catch (e) {
      AppLogger.e('Failed to initialize local storage', e);
      throw StorageFailure('Failed to initialize storage: ${e.toString()}');
    }
  }

  Future<String> saveEncryptedAudio(File audioFile, String sessionId) async {
    try {
      if (_recordingsDirectory == null) {
        await initialize();
      }

      // Validate file exists and has content
      if (!await audioFile.exists()) {
        throw StorageFailure('Audio file does not exist: ${audioFile.path}');
      }

      final fileSize = await audioFile.length();
      if (fileSize == 0) {
        throw StorageFailure('Audio file is empty: ${audioFile.path}');
      }

      AppLogger.i('Reading audio file: ${audioFile.path}, size: $fileSize bytes');

      // Read audio file
      final audioData = await audioFile.readAsBytes();

      if (audioData.isEmpty) {
        throw StorageFailure('Audio file read as empty bytes');
      }

      AppLogger.i('Audio data read: ${audioData.length} bytes, encrypting...');

      // Encrypt audio data
      final encrypted = await _encryptionService.encryptData(audioData);

      // Save encrypted file
      final encryptedFilePath = path.join(
        _recordingsDirectory!.path,
        '$sessionId.encrypted',
      );
      final encryptedFile = File(encryptedFilePath);
      await encryptedFile.writeAsBytes(encrypted.bytes);

      AppLogger.i('Audio encrypted and saved: $encryptedFilePath');
      return encryptedFilePath;
    } catch (e) {
      AppLogger.e('Failed to save encrypted audio', e);
      throw StorageFailure('Failed to save audio: ${e.toString()}');
    }
  }

  Future<File> decryptAndGetAudio(String encryptedFilePath) async {
    try {
      final encryptedFile = File(encryptedFilePath);
      if (!await encryptedFile.exists()) {
        throw const StorageFailure('Encrypted file not found');
      }

      final encryptedData = Encrypted(await encryptedFile.readAsBytes());
      final decryptedData = await _encryptionService.decryptData(encryptedData);

      // Create temporary decrypted file
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = path.join(
        tempDir.path,
        path.basenameWithoutExtension(encryptedFilePath),
      );
      final tempFile = File(tempFilePath);
      await tempFile.writeAsBytes(decryptedData);

      return tempFile;
    } catch (e) {
      AppLogger.e('Failed to decrypt audio', e);
      throw StorageFailure('Failed to decrypt audio: ${e.toString()}');
    }
  }

  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        AppLogger.i('File deleted: $filePath');
      }
    } catch (e) {
      AppLogger.e('Failed to delete file', e);
      throw StorageFailure('Failed to delete file: ${e.toString()}');
    }
  }

  Future<List<File>> getStoredRecordings() async {
    try {
      if (_recordingsDirectory == null) {
        await initialize();
      }

      if (!await _recordingsDirectory!.exists()) {
        return [];
      }

      final files = _recordingsDirectory!
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.encrypted'))
          .toList();

      return files;
    } catch (e) {
      AppLogger.e('Failed to get stored recordings', e);
      return [];
    }
  }

  Future<int> getFileSize(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        return await file.length();
      }
      return 0;
    } catch (e) {
      AppLogger.e('Failed to get file size', e);
      return 0;
    }
  }
}
