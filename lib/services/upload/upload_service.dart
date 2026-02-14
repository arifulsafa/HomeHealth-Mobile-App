import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../../core/utils/logger.dart';
import '../../core/errors/failures.dart';
import '../../core/constants/app_constants.dart';
import '../storage/local_storage_service.dart';
import '../network/api_client.dart';

class UploadService {
  final LocalStorageService _storageService = LocalStorageService();
  final ApiClient _apiClient;
  final Connectivity _connectivity = Connectivity();

  UploadService(this._apiClient);

  Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<String> uploadAudioFile({
    required String sessionId,
    required String encryptedFilePath,
    required String patientIdentifier,
    required List<String> formTypes,
    required int duration,
    String? notes,
    Function(int, int)? onProgress,
  }) async {
    try {
      if (!await isConnected()) {
        throw UploadFailure('No internet connection');
      }

      // Decrypt audio file for upload
      final decryptedFile = await _storageService.decryptAndGetAudio(
        encryptedFilePath,
      );

      // Backend API endpoint: POST /api/recordings/:sessionId/upload
      final uploadUrl = '/recordings/$sessionId/upload';
      final fullUploadUrl = '${_apiClient.baseUrl}$uploadUrl';

      // Ensure required fields are non-empty for backend validation
      final safePatientIdentifier =
          patientIdentifier.trim().isEmpty ? 'temp_patient' : patientIdentifier.trim();

      // Clean and de-duplicate form types.
      // These must already match backend ALLOWED_FORM_TYPES
      // (PT Oasis, PT Discharge, PT Evaluation, PT Oasis Discharge).
      final cleanedTypes = formTypes
          .where((t) => t.trim().isNotEmpty)
          .map((t) => t.trim())
          .toSet()
          .toList();

      // If nothing came through, default to a safe single form type.
      final safeFormTypes =
          cleanedTypes.isEmpty ? 'PT Oasis' : cleanedTypes.join(',');

      // Create form data matching backend API requirements
      final formMap = <String, dynamic>{
        'audio': await MultipartFile.fromFile(
          decryptedFile.path,
          filename: '$sessionId.m4a', // Backend expects .m4a, .aac, or .mp3
        ),
        'patientIdentifier': safePatientIdentifier,
        'formTypes': safeFormTypes, // Comma-separated as per backend API
        'duration': duration, // seconds
      };
      if (notes != null && notes.trim().isNotEmpty) {
        formMap['notes'] = notes.trim();
      }

      final formData = FormData.fromMap(formMap);

      final payloadLog = {
        'audio': {
          'path': decryptedFile.path,
          'filename': '$sessionId.m4a',
        },
        'patientIdentifier': safePatientIdentifier,
        'formTypes': safeFormTypes,
        'duration': duration,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      };
      AppLogger.i('Uploading audio file: $sessionId');
      AppLogger.i('Upload endpoint: $uploadUrl');
      AppLogger.i('Upload full URL: $fullUploadUrl');
      AppLogger.i('Upload payload: $payloadLog');
      AppLogger.i('Upload note: $notes');

      
      // Upload with progress tracking using ApiClient (includes auth token automatically)
      final response = await _apiClient.postMultipart(
        uploadUrl,
        formData: formData,
        onSendProgress: onProgress,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        AppLogger.i('Audio uploaded successfully: $sessionId');
        
        // Clean up decrypted temp file
        await decryptedFile.delete();
        
        // Extract audioFileUrl from backend response
        final audioFileUrl = response.data['audioFileUrl'] as String?;
        if (audioFileUrl == null || audioFileUrl.isEmpty) {
          AppLogger.w('Backend did not return audioFileUrl in response');
          throw UploadFailure('Upload succeeded but no audioFileUrl returned');
        }
        
        return audioFileUrl;
      } else {
        throw UploadFailure('Upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      AppLogger.e('Upload failed', e);
      if (e is Failure) {
        rethrow;
      }
      if (e is DioException) {
        throw UploadFailure('Network error: ${e.message}');
      }
      throw UploadFailure('Upload failed: ${e.toString()}');
    }
  }

  Future<String> uploadWithRetry({
    required String sessionId,
    required String encryptedFilePath,
    required String patientIdentifier,
    required List<String> formTypes,
    required int duration,
    String? notes,
    Function(int, int)? onProgress,
    int maxAttempts = AppConstants.maxRetryAttempts,
  }) async {
    int attempt = 0;
    Exception? lastError;

    while (attempt < maxAttempts) {
      try {
        final audioFileUrl = await uploadAudioFile(
          sessionId: sessionId,
          encryptedFilePath: encryptedFilePath,
          patientIdentifier: patientIdentifier,
          formTypes: formTypes,
          duration: duration,
          notes: notes,
          onProgress: onProgress,
        );
        AppLogger.i('Upload successful after ${attempt + 1} attempt(s)');
        return audioFileUrl;
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        attempt++;

        if (attempt < maxAttempts) {
          final delay = _calculateRetryDelay(attempt);
          AppLogger.w(
            'Upload attempt $attempt failed. Retrying in ${delay}s...',
          );
          await Future.delayed(Duration(seconds: delay));
        }
      }
    }

    AppLogger.e('Upload failed after $maxAttempts attempts');
    throw UploadFailure(
      'Upload failed after $maxAttempts attempts: ${lastError?.toString()}',
    );
  }

  int _calculateRetryDelay(int attempt) {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s
    return (1 << (attempt - 1)).clamp(1, 60);
  }
}
