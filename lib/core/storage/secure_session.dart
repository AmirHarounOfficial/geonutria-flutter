import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the lightweight session the backend uses for auth.
///
/// The backend has no JWT/bearer scheme: `/login` returns a `user_token_{id}`
/// string and every authenticated call simply carries `user_id` as a query
/// param (GET) or body field (POST). We persist [userId] (the credential) plus
/// the token and a few cached profile bits so the user stays logged in across
/// restarts (the web app only kept these in memory).
class SecureSession {
  SecureSession({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kUserId = 'user_id';
  static const _kToken = 'token';
  static const _kRole = 'role';
  static const _kLocale = 'locale';
  static const _kThemeMode = 'theme_mode';

  // In-memory cache so synchronous code (e.g. Dio interceptor) can read the
  // current user id without awaiting storage on every request.
  int? _cachedUserId;

  int? get userId => _cachedUserId;

  Future<void> load() async {
    final raw = await _storage.read(key: _kUserId);
    _cachedUserId = raw == null ? null : int.tryParse(raw);
  }

  Future<void> save({
    required int userId,
    required String token,
    String? role,
  }) async {
    _cachedUserId = userId;
    await _storage.write(key: _kUserId, value: '$userId');
    await _storage.write(key: _kToken, value: token);
    if (role != null) await _storage.write(key: _kRole, value: role);
  }

  Future<String?> get token => _storage.read(key: _kToken);
  Future<String?> get role => _storage.read(key: _kRole);

  bool get isLoggedIn => _cachedUserId != null;

  // --- UI preferences (not security-sensitive but kept in one place) ---

  Future<String?> readLocale() => _storage.read(key: _kLocale);
  Future<void> writeLocale(String code) =>
      _storage.write(key: _kLocale, value: code);

  Future<String?> readThemeMode() => _storage.read(key: _kThemeMode);
  Future<void> writeThemeMode(String mode) =>
      _storage.write(key: _kThemeMode, value: mode);

  Future<void> clear() async {
    _cachedUserId = null;
    await _storage.delete(key: _kUserId);
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kRole);
  }
}
