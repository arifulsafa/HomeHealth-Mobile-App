import 'environment_config.dart';

class AppConfig {
  static const String appName = 'HealthDoc';
  static const String appTagline = 'Home Health Documentation Platform';
  
  // API Configuration (loaded from environment)
  static String apiBaseUrl = EnvironmentConfig.apiBaseUrl;
  static const int apiTimeout = 30000; // 30 seconds
  
  // Audio Configuration
  static const int audioSampleRate = 16000; // 16kHz
  static const int audioChannels = 1; // Mono
  static const String audioFormat = 'm4a';
  
  // Storage Configuration
  static const int localRetentionDays = 30;
  static const int maxRetryAttempts = 5;
  static const int retryDelaySeconds = 60;
  
  // Session Configuration
  static const int sessionTimeoutMinutes = 30;
  
  // Encryption Configuration
  static const String encryptionAlgorithm = 'AES-256';
  
  static Future<void> initialize() async {
    // API URL is loaded from EnvironmentConfig
    apiBaseUrl = EnvironmentConfig.apiBaseUrl;
  }
}
