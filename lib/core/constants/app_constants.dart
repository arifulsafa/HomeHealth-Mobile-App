class AppConstants {
  // App Info
  static const String appName = 'HealthDoc';
  static const String appTagline = 'Home Health Documentation Platform';

  // Form Types
  static const String formTypePTOasis = 'PT Oasis';
  static const String formTypePTDischarge = 'PT Discharge';
  static const String formTypePTEvaluation = 'PT Evaluation';
  static const String formTypePTOasisDischarge = 'PT Oasis Discharge';

  static const List<String> allFormTypes = [
    formTypePTOasis,
    formTypePTDischarge,
    formTypePTEvaluation,
    formTypePTOasisDischarge,
  ];

  // Recording Status
  static const String statusRecording = 'recording';
  static const String statusUploading = 'uploading';
  static const String statusProcessing = 'processing';
  static const String statusCompleted = 'completed';
  static const String statusFailed = 'failed';

  // Storage Keys
  static const String keyAuthToken = 'auth_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyEncryptionKey = 'encryption_key';

  // File Paths
  static const String recordingsDirectory = 'recordings';
  static const String tempDirectory = 'temp';

  // Network
  static const int maxRetryAttempts = 5;
  static const int retryDelaySeconds = 60;
  static const int connectionTimeout = 30;
  static const int receiveTimeout = 60;

  // Session
  static const int sessionTimeoutMinutes = 30;
}
