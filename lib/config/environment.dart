enum Environment {
  development,
  staging,
  production,
}

// https://home-health-document-vbnx.bolt.host

class EnvironmentConfig {
  static Environment current = Environment.development;

  static String get apiBaseUrl {
    switch (current) {
      case Environment.development:
        return 'https://sessions-to-google-docs-private-backend-production.up.railway.app/api';
      case Environment.staging:
        return 'https://sessions-to-google-docs-private-backend-production.up.railway.app/api';
      case Environment.production:
        return 'https://sessions-to-google-docs-private-backend-production.up.railway.app/api';
    }
  }

  static bool get isDevelopment => current == Environment.development;
  static bool get isProduction => current == Environment.production;
}
