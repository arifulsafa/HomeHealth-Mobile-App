import 'dart:async';
import '../../core/utils/logger.dart';
import '../domain/entities/recording_session.dart';
import 'upload/upload_queue_manager.dart';
import 'storage/file_retention_service.dart';
import 'storage/local_storage_service.dart';
import 'storage/recording_session_store.dart';
import 'network/api_client.dart';

/// Initializes app-wide services like upload queue and file retention
class AppServiceInitializer {
  static UploadQueueManager? _uploadQueueManager;
  static FileRetentionService? _fileRetentionService;
  static LocalStorageService? _storageService;
  static RecordingSessionStore? _recordingSessionStore;
  static Timer? _cleanupTimer;

  /// Initialize all app services
  static Future<void> initialize() async {
    try {
      AppLogger.i('Initializing app services...');

      // Initialize storage service
      _storageService = LocalStorageService();
      await _storageService!.initialize();

      // Initialize recording session store (local index for pending/failed uploads)
      _recordingSessionStore = RecordingSessionStore(storageService: _storageService);
      await _recordingSessionStore!.initialize();

      // Initialize API client for upload service
      final apiClient = ApiClient();

      // Initialize upload queue manager
      _uploadQueueManager = UploadQueueManager(apiClient, _recordingSessionStore!);
      await _uploadQueueManager!.initialize();

      // Initialize file retention service
      _fileRetentionService = FileRetentionService();

      // Run initial cleanup
      await _runFileRetentionCleanup();

      // Schedule periodic cleanup (daily)
      _schedulePeriodicCleanup();

      AppLogger.i('App services initialized successfully');
    } catch (e) {
      AppLogger.e('Failed to initialize app services', e);
      rethrow;
    }
  }

  /// Run file retention cleanup
  static Future<void> _runFileRetentionCleanup() async {
    try {
      if (_fileRetentionService == null || _storageService == null) return;

      // Use locally-tracked completed sessions as "uploaded" for retention cleanup.
      final uploadedSessionIds = <String>[];
      final store = _recordingSessionStore;
      if (store != null) {
        final sessions = await store.getAll();
        uploadedSessionIds.addAll(
          sessions
              .where((s) => s.status == RecordingStatus.completed)
              .map((s) => s.id),
        );
      }

      final deletedCount = await _fileRetentionService!.cleanupOldFiles(
        uploadedSessionIds: uploadedSessionIds,
      );

      if (deletedCount > 0) {
        AppLogger.i('File retention cleanup: $deletedCount files deleted');
      }
    } catch (e) {
      AppLogger.e('File retention cleanup failed', e);
    }
  }

  /// Schedule periodic file retention cleanup (runs daily)
  static void _schedulePeriodicCleanup() {
    // Cancel existing timer if any
    _cleanupTimer?.cancel();

    // Calculate time until next midnight
    final now = DateTime.now();
    final nextMidnight = DateTime(
      now.year,
      now.month,
      now.day + 1,
      0,
      0,
      0,
    );
    final delay = nextMidnight.difference(now);

    // Schedule first cleanup at midnight
    _cleanupTimer = Timer(delay, () {
      _runFileRetentionCleanup();
      // Then schedule daily cleanup
      _cleanupTimer = Timer.periodic(
        const Duration(days: 1),
        (_) => _runFileRetentionCleanup(),
      );
    });

    AppLogger.i('File retention cleanup scheduled');
  }

  /// Get upload queue manager instance
  static UploadQueueManager? get uploadQueueManager => _uploadQueueManager;

  static RecordingSessionStore? get recordingSessionStore => _recordingSessionStore;

  /// Dispose all services
  static Future<void> dispose() async {
    _cleanupTimer?.cancel();
    await _uploadQueueManager?.dispose();
    await _recordingSessionStore?.dispose();
    AppLogger.i('App services disposed');
  }
}
