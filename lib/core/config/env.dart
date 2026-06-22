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

  /// Base used to resolve relative `/static/...` media paths returned by the
  /// backend (satellite plots, profile/asset images). These are served by the
  /// FastAPI app, which lives behind nginx at `/api` — exactly like the web
  /// frontend, which prefixes such paths with its `/api` base. So this must
  /// include `/api` (otherwise the path hits the frontend's own assets and
  /// 404s).
  static const String staticBaseUrl = String.fromEnvironment(
    'STATIC_BASE_URL',
    defaultValue: 'https://app.geonutria.ai/api',
  );

  /// WebSocket base for the support chat (`$wsBaseUrl/support/ws/{userId}`).
  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'wss://app.geonutria.ai/api',
  );

  /// Google OAuth **web/server** client id (same Google Cloud project the
  /// backend uses). Passed to GoogleSignIn as `serverClientId` so Android issues
  /// tokens with the right audience — the recommended setup that avoids the
  /// common DEVELOPER_ERROR. The Android & iOS native client ids are matched by
  /// package/SHA and the iOS Info.plist respectively, not here.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue: '934884489582-4logkq2nh414npcv1tkvtrs8cplnonlb.apps.googleusercontent.com',
  );

  /// Resolve a possibly-relative media path to an absolute URL.
  static String resolveMedia(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$staticBaseUrl$normalized';
  }
}
