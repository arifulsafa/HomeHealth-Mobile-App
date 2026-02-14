/// Environment configuration for the app
/// Update these values based on your backend deployment
class EnvironmentConfig { //http://172.20.10.13:3000/api
  // Backend API URL https://sessions-to-google-docs-private-backend-production.up.railway.app/api';
  // For local development: 'http://localhost:3000/api'
  // For production: 'https://your-backend-domain.com/api'
  static const String apiBaseUrl = 'https://sessions-to-google-docs-private-backend-production.up.railway.app/api';
  
  // Environment
  static const String environment = 'development'; // 'development' or 'production'
  
  // Enable debug logging
  static const bool enableDebugLogging = true;
}
