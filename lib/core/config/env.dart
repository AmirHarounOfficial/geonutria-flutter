/// Environment configuration for the GeoNutria mobile app.
///
/// In production the React frontend talks to the backend through nginx at
/// `/api`, which strips the prefix and proxies to FastAPI on :8009. The mobile
/// app is a native client (not subject to CORS) and points straight at the
/// public `/api` base. Override [apiBaseUrl] / [staticBaseUrl] at build time
/// with `--dart-define` for local/staging testing.
class Env {
  Env._();

  /// Base URL for all REST calls. Endpoints are appended verbatim
  /// (e.g. `$apiBaseUrl/login`, `$apiBaseUrl/iot-status`).
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://app.geonutria.ai/api',
  );

  /// Host used to resolve relative `/static/...` media paths returned by the
  /// backend (image/output/satellite URLs).
  static const String staticBaseUrl = String.fromEnvironment(
    'STATIC_BASE_URL',
    defaultValue: 'https://app.geonutria.ai',
  );

  /// WebSocket base for the support chat (`$wsBaseUrl/support/ws/{userId}`).
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://app.geonutria.ai/api',
  );

  /// Google OAuth client id (web client id used by the backend's
  /// `/google-login` verification). Supplied later by the project owner.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '',
  );

  /// Resolve a possibly-relative media path to an absolute URL.
  static String resolveMedia(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$staticBaseUrl$normalized';
  }
}
