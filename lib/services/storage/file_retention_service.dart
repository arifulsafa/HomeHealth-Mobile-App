import 'dart:io';
import 'package:path/path.dart' as path;
import '../../core/utils/logger.dart';
import '../../config/app_config.dart';
import '../storage/local_storage_service.dart';

class FileRetentionService {
  final LocalStorageService _storageService = LocalStorageService();

  /// Clean up files older than retention period
  /// Only deletes files that have been successfully uploaded
  Future<int> cleanupOldFiles({
    required List<String> uploadedSessionIds,
    int retentionDays = AppConfig.localRetentionDays,
  }) async {
    try {
      final recordingsDir = await _storageService.initialize();
      if (!await recordingsDir.exists()) {
        return 0;
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
      int deletedCount = 0;

      final files = recordingsDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.encrypted'))
          .toList();

      for (final file in files) {
        try {
          // Extract session ID from filename (format: sessionId.encrypted)
          final filename = path.basenameWithoutExtension(file.path);
          
          // Check if file is older than retention period
          final fileStat = await file.stat();
          final fileModified = fileStat.modified;

          if (fileModified.isBefore(cutoffDate)) {
            // Only delete if it's been uploaded
            if (uploadedSessionIds.contains(filename)) {
              await file.delete();
              deletedCount++;
              AppLogger.i('Deleted old file: ${file.path}');
            } else {
              AppLogger.w(
                'File ${file.path} is old but not uploaded, keeping for retry',
              );
            }
          }
        } catch (e) {
          AppLogger.e('Error processing file ${file.path}', e);
        }
      }

      AppLogger.i('File retention cleanup completed: $deletedCount files deleted');
      return deletedCount;
    } catch (e) {
      AppLogger.e('File retention cleanup failed', e);
      return 0;
    }
  }

  /// Get list of files that should be deleted (older than retention period)
  Future<List<File>> getFilesToDelete({
    required List<String> uploadedSessionIds,
    int retentionDays = AppConfig.localRetentionDays,
  }) async {
    try {
      final recordingsDir = await _storageService.initialize();
      if (!await recordingsDir.exists()) {
        return [];
      }

      final cutoffDate = DateTime.now().subtract(Duration(days: retentionDays));
      final filesToDelete = <File>[];

      final files = recordingsDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.encrypted'))
          .toList();

      for (final file in files) {
        try {
          final filename = path.basenameWithoutExtension(file.path);
          final fileStat = await file.stat();
          final fileModified = fileStat.modified;

          if (fileModified.isBefore(cutoffDate) &&
              uploadedSessionIds.contains(filename)) {
            filesToDelete.add(file);
          }
        } catch (e) {
          AppLogger.e('Error checking file ${file.path}', e);
        }
      }

      return filesToDelete;
    } catch (e) {
      AppLogger.e('Failed to get files to delete', e);
      return [];
    }
  }

  /// Get total size of stored recordings
  Future<int> getTotalStorageSize() async {
    try {
      final recordingsDir = await _storageService.initialize();
      if (!await recordingsDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      final files = recordingsDir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.encrypted'))
          .toList();

      for (final file in files) {
        try {
          totalSize += await file.length();
        } catch (e) {
          AppLogger.e('Error getting size for ${file.path}', e);
        }
      }

      return totalSize;
    } catch (e) {
      AppLogger.e('Failed to get total storage size', e);
      return 0;
    }
  }
}
