import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/entities/recording_session.dart';
import '../../core/utils/logger.dart';
import '../../core/errors/failures.dart';
import '../storage/recording_session_store.dart';
import '../network/api_client.dart';
import 'upload_service.dart';

class UploadQueueManager {
  final UploadService _uploadService;
  final RecordingSessionStore _sessionStore;
  final Connectivity _connectivity = Connectivity();

  UploadQueueManager(ApiClient apiClient, this._sessionStore)
      : _uploadService = UploadService(apiClient);
  
  final List<RecordingSession> _queue = [];
  final StreamController<RecordingSession> _uploadProgressController =
      StreamController<RecordingSession>.broadcast();
  
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isUploading = false;
  bool _isMonitoring = false;

  Stream<RecordingSession> get uploadProgress => _uploadProgressController.stream;
  List<RecordingSession> get pendingUploads => List.unmodifiable(_queue);
  Stream<void> get sessionChanges => _sessionStore.changes;

  /// Initialize the upload queue manager and start monitoring network
  Future<void> initialize() async {
    if (_isMonitoring) return;
    
    _isMonitoring = true;

    // Initialize local session store and restore any pending/failed sessions
    await _sessionStore.initialize();
    await _restoreQueueFromStore();
    
    // Start monitoring connectivity
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (ConnectivityResult result) {
        if (result != ConnectivityResult.none) {
          AppLogger.i('Network available, processing upload queue');
          _processQueue();
        } else {
          AppLogger.i('Network unavailable, pausing uploads');
        }
      },
    );

    // Process queue on initialization if network is available
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      _processQueue();
    }
  }

  Future<void> _restoreQueueFromStore() async {
    try {
      final sessions = await _sessionStore.getAll();
      final toRestore = sessions.where((s) {
        final restorableStatus = s.status == RecordingStatus.failed ||
            s.status == RecordingStatus.processing ||
            s.status == RecordingStatus.uploading;
        return restorableStatus && s.encryptedFilePath != null;
      }).toList();

      for (final s in toRestore) {
        if (_queue.any((q) => q.id == s.id)) continue;
        _queue.add(s);
      }

      if (toRestore.isNotEmpty) {
        AppLogger.i('Restored ${toRestore.length} session(s) into upload queue');
      }
    } catch (e) {
      AppLogger.e('Failed to restore upload queue from store', e);
    }
  }

  /// Add a recording session to the upload queue
  Future<void> enqueue(RecordingSession session) async {
    if (session.encryptedFilePath == null) {
      throw UploadFailure('Cannot enqueue session without encrypted file path');
    }

    // Check if already in queue
    if (_queue.any((s) => s.id == session.id)) {
      AppLogger.w('Session ${session.id} already in queue');
      return;
    }

    final queuedSession = session.copyWith(
      status: RecordingStatus.processing, // treated as "queued"
      uploadError: null,
    );

    await _sessionStore.upsert(queuedSession);
    _queue.add(queuedSession);
    AppLogger.i(
      'Session ${queuedSession.id} added to upload queue (${_queue.length} pending)',
    );
    
    // Try to process immediately if network is available
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult != ConnectivityResult.none && !_isUploading) {
      _processQueue();
    }
  }

  /// Remove a session from the queue
  void removeFromQueue(String sessionId) {
    _queue.removeWhere((s) => s.id == sessionId);
    AppLogger.i('Session $sessionId removed from queue');
  }

  /// Process the upload queue
  Future<void> _processQueue() async {
    if (_isUploading || _queue.isEmpty) return;

    _isUploading = true;

    while (_queue.isNotEmpty) {
      final session = _queue.first;
      
      // Check network availability
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        AppLogger.w('Network unavailable, stopping queue processing');
        _isUploading = false;
        return;
      }

      try {
        // Update status to uploading
        final uploadingSession = session.copyWith(
          status: RecordingStatus.uploading,
          uploadAttempts: (session.uploadAttempts ?? 0) + 1,
          uploadError: null,
        );
        _updateQueueItem(uploadingSession);
        await _sessionStore.upsert(uploadingSession);
        _uploadProgressController.add(uploadingSession);

        // Upload the file
        final audioFileUrl = await _uploadService.uploadWithRetry(
          sessionId: session.id,
          encryptedFilePath: session.encryptedFilePath!,
          patientIdentifier: session.patientIdentifier,
          formTypes: session.formTypes,
          duration: session.duration,
          notes: session.notes,
          onProgress: (sent, total) {
            // Could emit progress updates here if needed
          },
        );

        // Upload successful
        final completedSession = uploadingSession.copyWith(
          status: RecordingStatus.completed,
          uploadedAt: DateTime.now(),
          audioFileUrl: audioFileUrl,
        );
        _updateQueueItem(completedSession);
        await _sessionStore.upsert(completedSession);
        _uploadProgressController.add(completedSession);

        // Remove from queue
        _queue.removeAt(0);
        AppLogger.i('Session ${session.id} uploaded successfully');

      } catch (e) {
        AppLogger.e('Upload failed for session ${session.id}', e);
        
        final failedSession = _queue.first.copyWith(
          status: RecordingStatus.failed,
          uploadError: e.toString(),
        );
        _updateQueueItem(failedSession);
        await _sessionStore.upsert(failedSession);
        _uploadProgressController.add(failedSession);

        // If max retries reached, remove from queue (user can manually retry later)
        if ((failedSession.uploadAttempts ?? 0) >= 5) {
          AppLogger.w('Max retries reached for session ${session.id}, removing from queue');
          _queue.removeAt(0);
        } else {
          // Move to end of queue for retry
          _queue.removeAt(0);
          _queue.add(failedSession);
        }
      }
    }

    _isUploading = false;
    AppLogger.i('Upload queue processing completed');
  }

  /// Update an item in the queue
  void _updateQueueItem(RecordingSession updatedSession) {
    final index = _queue.indexWhere((s) => s.id == updatedSession.id);
    if (index != -1) {
      _queue[index] = updatedSession;
    }
  }

  /// Manually trigger queue processing
  Future<void> processQueue() async {
    await _processQueue();
  }

  /// Manually retry a failed session (resets attempts)
  Future<void> retry(String sessionId) async {
    final session = await _sessionStore.getById(sessionId);
    if (session == null) {
      throw UploadFailure('Session not found: $sessionId');
    }
    if (session.encryptedFilePath == null) {
      throw UploadFailure('No encrypted file for session: $sessionId');
    }

    // Remove any existing queue entries
    _queue.removeWhere((s) => s.id == sessionId);

    final reset = session.copyWith(
      status: RecordingStatus.processing,
      uploadAttempts: 0,
      uploadError: null,
    );

    await enqueue(reset);
  }

  /// Dispose resources
  Future<void> dispose() async {
    _isMonitoring = false;
    await _connectivitySubscription?.cancel();
    await _uploadProgressController.close();
  }
}
