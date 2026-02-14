import '../../core/errors/failures.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/remote_recording.dart';
import '../../services/network/api_client.dart';

class RecordingsRepository {
  final ApiClient _apiClient;

  RecordingsRepository(this._apiClient);

  /// GET /api/recordings (paginated list with optional filters)
  Future<PaginatedRecordings> fetchRecordings({
    int page = 1,
    int limit = 20,
    String? status,
    String? patientIdentifier,
    String? sessionId,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final qp = <String, dynamic>{
        'page': page,
        'limit': limit.clamp(1, 100),
      };
      if (status != null && status.trim().isNotEmpty) {
        qp['status'] = status.trim();
      }
      if (patientIdentifier != null && patientIdentifier.trim().isNotEmpty) {
        qp['patientIdentifier'] = patientIdentifier.trim();
      }
      if (sessionId != null && sessionId.trim().isNotEmpty) {
        qp['sessionId'] = sessionId.trim();
      }
      if (fromDate != null) {
        qp['fromDate'] = fromDate.toUtc().toIso8601String();
      }
      if (toDate != null) {
        qp['toDate'] = toDate.toUtc().toIso8601String();
      }

      final res = await _apiClient.get('/recordings', queryParameters: qp);
      final data = res.data;
      if (data is! Map) {
        throw ServerFailure('Unexpected response from /recordings');
      }

      final parsed = PaginatedRecordings.fromJson(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
      return parsed;
    } catch (e) {
      AppLogger.e('Failed to fetch recordings', e);
      if (e is Failure) rethrow;
      throw ServerFailure('Failed to fetch recordings: ${e.toString()}');
    }
  }

  /// GET /api/recordings/:sessionId
  Future<RemoteRecording> fetchRecordingBySessionId(String sessionId) async {
    try {
      final res = await _apiClient.get('/recordings/$sessionId');
      final data = res.data;
      if (data is! Map) {
        throw ServerFailure('Unexpected response from /recordings/$sessionId');
      }

      return RemoteRecording.fromJson(
        data.map((k, v) => MapEntry(k.toString(), v)),
      );
    } catch (e) {
      AppLogger.e('Failed to fetch recording by sessionId', e);
      if (e is Failure) rethrow;
      throw ServerFailure('Failed to fetch recording: ${e.toString()}');
    }
  }

  /// GET /api/patients/search?query=&limit=
  Future<List<String>> searchPatients({
    String query = '',
    int limit = 20,
  }) async {
    try {
      final qp = <String, dynamic>{
        'query': query,
        'limit': limit.clamp(1, 50),
      };
      final res = await _apiClient.get('/patients/search', queryParameters: qp);
      final data = res.data;
      if (data is! Map) {
        throw ServerFailure('Unexpected response from /patients/search');
      }
      final patients = data['patients'];
      if (patients is List) {
        return patients.map((e) => e.toString()).toList();
      }
      return const <String>[];
    } catch (e) {
      AppLogger.e('Failed to search patients', e);
      if (e is Failure) rethrow;
      throw ServerFailure('Failed to search patients: ${e.toString()}');
    }
  }
}

