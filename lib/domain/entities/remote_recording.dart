import 'package:equatable/equatable.dart';

class RemoteRecording extends Equatable {
  final String id;
  final String sessionId;
  final String userId;
  final String patientIdentifier;
  final List<String> formTypes;
  final String? audioFileUrl;
  final int duration;
  final String status;
  final DateTime? uploadedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? manualNotes;
  final String? aiGeneratedNotes;
  final String? transcriptText;

  const RemoteRecording({
    required this.id,
    required this.sessionId,
    required this.userId,
    required this.patientIdentifier,
    required this.formTypes,
    required this.audioFileUrl,
    required this.duration,
    required this.status,
    required this.uploadedAt,
    required this.createdAt,
    required this.updatedAt,
    this.manualNotes,
    this.aiGeneratedNotes,
    this.transcriptText,
  });

  static DateTime? _date(dynamic v) {
    if (v == null) return null;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  factory RemoteRecording.fromJson(Map<String, dynamic> json) {
    // Handle optional nested transcript object from backend
    final transcript = json['transcript'];
    String? transcriptText;
    if (transcript is Map) {
      final t = transcript['text'];
      if (t != null && t.toString().trim().isNotEmpty) {
        transcriptText = t.toString();
      }
    }

    return RemoteRecording(
      id: (json['id'] ?? '').toString(),
      sessionId: (json['sessionId'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      patientIdentifier: (json['patientIdentifier'] ?? '').toString(),
      formTypes: (json['formTypes'] is List)
          ? (json['formTypes'] as List).map((e) => e.toString()).toList()
          : const <String>[],
      audioFileUrl: json['audioFileUrl']?.toString(),
      duration: (json['duration'] is num) ? (json['duration'] as num).toInt() : 0,
      status: (json['status'] ?? '').toString(),
      uploadedAt: _date(json['uploadedAt']),
      createdAt: _date(json['createdAt']) ?? DateTime.now(),
      updatedAt: _date(json['updatedAt']) ?? DateTime.now(),
      // Optional notes fields – backend may use different keys, so we check a few.
      manualNotes: json['notes']?.toString() ??
          json['manualNotes']?.toString() ??
          json['handwrittenNotes']?.toString() ??
          json['notesManual']?.toString(),
      aiGeneratedNotes: json['aiGeneratedNotes']?.toString() ??
          json['aiNotes']?.toString() ??
          json['aiGenerated']?.toString(),
      transcriptText: transcriptText,
    );
  }

  @override
  List<Object?> get props => [
        id,
        sessionId,
        userId,
        patientIdentifier,
        formTypes,
        audioFileUrl,
        duration,
        status,
        uploadedAt,
        createdAt,
        updatedAt,
        manualNotes,
        aiGeneratedNotes,
        transcriptText,
      ];
}

class PaginatedRecordings extends Equatable {
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final List<RemoteRecording> recordings;

  const PaginatedRecordings({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.recordings,
  });

  factory PaginatedRecordings.fromJson(Map<String, dynamic> json) {
    final list = json['recordings'];
    return PaginatedRecordings(
      page: (json['page'] is num) ? (json['page'] as num).toInt() : 1,
      limit: (json['limit'] is num) ? (json['limit'] as num).toInt() : 20,
      total: (json['total'] is num) ? (json['total'] as num).toInt() : 0,
      totalPages:
          (json['totalPages'] is num) ? (json['totalPages'] as num).toInt() : 1,
      recordings: (list is List)
          ? list
              .whereType<Map>()
              .map((e) => RemoteRecording.fromJson(
                    e.map((k, v) => MapEntry(k.toString(), v)),
                  ))
              .toList()
          : const <RemoteRecording>[],
    );
  }

  @override
  List<Object?> get props => [page, limit, total, totalPages, recordings];
}

