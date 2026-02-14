import 'package:equatable/equatable.dart';

enum RecordingStatus {
  recording,
  paused,
  uploading,
  processing,
  completed,
  failed,
}

class RecordingSession extends Equatable {
  final String id;
  final String userId;
  final String patientIdentifier;
  final List<String> formTypes;
  final String? audioFilePath; // Unencrypted original path (temporary)
  final String? encryptedFilePath; // Encrypted file path (persistent)
  final String? audioFileUrl; // Server URL after upload
  final int duration; // in seconds
  final RecordingStatus status;
  final DateTime? uploadedAt;
  final DateTime createdAt;
  final DateTime? localRetentionUntil;
  final int? uploadAttempts;
  final String? uploadError;
  final String? notes; // Optional notes captured at start of session

  const RecordingSession({
    required this.id,
    required this.userId,
    required this.patientIdentifier,
    required this.formTypes,
    this.audioFilePath,
    this.encryptedFilePath,
    this.audioFileUrl,
    required this.duration,
    required this.status,
    this.uploadedAt,
    required this.createdAt,
    this.localRetentionUntil,
    this.uploadAttempts,
    this.uploadError,
    this.notes,
  });

  RecordingSession copyWith({
    String? id,
    String? userId,
    String? patientIdentifier,
    List<String>? formTypes,
    String? audioFilePath,
    String? encryptedFilePath,
    String? audioFileUrl,
    int? duration,
    RecordingStatus? status,
    DateTime? uploadedAt,
    DateTime? createdAt,
    DateTime? localRetentionUntil,
    int? uploadAttempts,
    String? uploadError,
    String? notes,
  }) {
    return RecordingSession(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      patientIdentifier: patientIdentifier ?? this.patientIdentifier,
      formTypes: formTypes ?? this.formTypes,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      encryptedFilePath: encryptedFilePath ?? this.encryptedFilePath,
      audioFileUrl: audioFileUrl ?? this.audioFileUrl,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      createdAt: createdAt ?? this.createdAt,
      localRetentionUntil: localRetentionUntil ?? this.localRetentionUntil,
      uploadAttempts: uploadAttempts ?? this.uploadAttempts,
      uploadError: uploadError ?? this.uploadError,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'patientIdentifier': patientIdentifier,
      'formTypes': formTypes,
      'audioFilePath': audioFilePath,
      'encryptedFilePath': encryptedFilePath,
      'audioFileUrl': audioFileUrl,
      'duration': duration,
      'status': status.name,
      'uploadedAt': uploadedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'localRetentionUntil': localRetentionUntil?.toIso8601String(),
      'uploadAttempts': uploadAttempts,
      'uploadError': uploadError,
      'notes': notes,
    };
  }

  static RecordingStatus _statusFromString(String? value) {
    if (value == null) return RecordingStatus.failed;
    for (final s in RecordingStatus.values) {
      if (s.name == value) return s;
    }
    return RecordingStatus.failed;
  }

  static DateTime? _dateFromIso(dynamic value) {
    if (value == null) return null;
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  factory RecordingSession.fromJson(Map<String, dynamic> json) {
    return RecordingSession(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      patientIdentifier: (json['patientIdentifier'] ?? '').toString(),
      formTypes: (json['formTypes'] is List)
          ? (json['formTypes'] as List).map((e) => e.toString()).toList()
          : const <String>[],
      audioFilePath: json['audioFilePath']?.toString(),
      encryptedFilePath: json['encryptedFilePath']?.toString(),
      audioFileUrl: json['audioFileUrl']?.toString(),
      duration: (json['duration'] is num) ? (json['duration'] as num).toInt() : 0,
      status: _statusFromString(json['status']?.toString()),
      uploadedAt: _dateFromIso(json['uploadedAt']),
      createdAt: _dateFromIso(json['createdAt']) ?? DateTime.now(),
      localRetentionUntil: _dateFromIso(json['localRetentionUntil']),
      uploadAttempts: (json['uploadAttempts'] is num)
          ? (json['uploadAttempts'] as num).toInt()
          : null,
      uploadError: json['uploadError']?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        patientIdentifier,
        formTypes,
        audioFilePath,
        encryptedFilePath,
        audioFileUrl,
        duration,
        status,
        uploadedAt,
        createdAt,
        localRetentionUntil,
        uploadAttempts,
        uploadError,
        notes,
      ];
}
