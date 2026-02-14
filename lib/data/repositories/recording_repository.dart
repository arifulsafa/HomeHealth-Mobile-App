// ignore_for_file: unused_local_variable

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import '../../domain/entities/recording_session.dart';
import '../../core/utils/logger.dart';
import '../../core/errors/failures.dart';
import '../../services/audio/audio_recording_service.dart';
import '../../services/storage/local_storage_service.dart';
import '../../services/upload/upload_service.dart';
import '../../config/app_config.dart';

class RecordingRepository {
  final AudioRecordingService _audioService;
  final LocalStorageService _storageService;
  final UploadService _uploadService;
  final Uuid _uuid = const Uuid();

  RecordingRepository(
    this._audioService,
    this._storageService,
    this._uploadService,
  );

  Future<RecordingSession> createSession({
    required String userId,
    required String patientIdentifier,
    required List<String> formTypes,
  }) async {
    try {
      final sessionId = _uuid.v4();
      final session = RecordingSession(
        id: sessionId,
        userId: userId,
        patientIdentifier: patientIdentifier,
        formTypes: formTypes,
        duration: 0,
        status: RecordingStatus.recording,
        createdAt: DateTime.now(),
        localRetentionUntil: DateTime.now().add(
          const Duration(days: AppConfig.localRetentionDays),
        ),
      );

      AppLogger.i('Recording session created: $sessionId');
      return session;
    } catch (e) {
      AppLogger.e('Failed to create session', e);
      throw RecordingFailure('Failed to create session: ${e.toString()}');
    }
  }

  Future<String> startRecording(String sessionId) async {
    try {
      // Get file path for recording
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory(
        path.join(appDir.path, 'recordings'),
      );
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      final filePath = path.join(
        recordingsDir.path,
        '$sessionId.${AppConfig.audioFormat}',
      );

      await _audioService.startRecording(filePath);
      return filePath;
    } catch (e) {
      AppLogger.e('Failed to start recording', e);
      throw RecordingFailure('Failed to start recording: ${e.toString()}');
    }
  }

  Future<String> stopRecording() async {
    try {
      final path = await _audioService.stopRecording();
      if (path == null) {
        throw RecordingFailure('No recording to stop');
      }
      return path;
    } catch (e) {
      AppLogger.e('Failed to stop recording', e);
      throw RecordingFailure('Failed to stop recording: ${e.toString()}');
    }
  }

  Future<String> saveEncryptedRecording(
    String sessionId,
    String audioFilePath,
  ) async {
    try {
      final audioFile = File(audioFilePath);
      final encryptedPath = await _storageService.saveEncryptedAudio(
        audioFile,
        sessionId,
      );
      return encryptedPath;
    } catch (e) {
      AppLogger.e('Failed to save encrypted recording', e);
      throw StorageFailure('Failed to save recording: ${e.toString()}');
    }
  }

  Future<void> uploadRecording({
    required RecordingSession session,
    Function(int, int)? onProgress,
  }) async {
    try {
      if (session.encryptedFilePath == null) {
        throw UploadFailure('No audio file to upload');
      }

      final audioFileUrl = await _uploadService.uploadWithRetry(
        sessionId: session.id,
        encryptedFilePath: session.encryptedFilePath!,
        patientIdentifier: session.patientIdentifier,
        formTypes: session.formTypes,
        duration: session.duration,
        notes: session.notes,
        onProgress: onProgress,
      );

      // Update session with uploaded URL
      // TODO: Update session in local database
      AppLogger.i('Recording uploaded: ${session.id}');
    } catch (e) {
      AppLogger.e('Failed to upload recording', e);
      throw UploadFailure('Failed to upload: ${e.toString()}');
    }
  }

  Stream<Duration> getRecordingDuration() {
    return _audioService.durationStream;
  }

  Future<bool> get isRecording async => _audioService.isRecording;

  Future<void> dispose() async {
    await _audioService.dispose();
  }
}
