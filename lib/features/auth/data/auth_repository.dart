import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_session.dart';
import '../../../core/utils/password.dart';
import 'auth_models.dart';

/// Talks to the backend's auth router (all routes at root, no prefix) and
/// persists the session via [SecureSession].
class AuthRepository {
  AuthRepository(this._api, this._session);

  final ApiClient _api;
  final SecureSession _session;

  /// `POST /login` — `{ username, password }`.
  Future<LoginResult> login(String username, String password) async {
    final data = await _api.post('/login', body: {
      'username': username,
      'password': bcryptSafePassword(password),
    });
    final map = _asMap(data);
    if (map['status'] != 'success') {
      throw AppException('${map['message'] ?? 'Login failed'}');
    }
    final result = LoginResult.fromJson(map);
    await _persist(result);
    return result;
  }

  /// `POST /google-login` — `{ token }`. Either logs in or signals onboarding.
  Future<GoogleLoginOutcome> googleLogin(String googleAccessToken) async {
    final data = await _api.post('/google-login', body: {
      'token': googleAccessToken,
    });
    final map = _asMap(data);
    if (map['status'] == 'requires_onboarding') {
      return GoogleLoginOutcome.needsOnboarding(GoogleOnboarding.fromJson(map));
    }
    final result = LoginResult.fromJson(map);
    await _persist(result);
    return GoogleLoginOutcome.loggedIn(result);
  }

  /// `POST /google-register` — completes Google sign-up after onboarding.
  Future<LoginResult> googleRegister({
    required String googleToken,
    required RegistrationData data,
  }) async {
    final res = await _api.post('/google-register', body: {
      'google_token': googleToken,
      ...data.toJson(includePassword: false),
    });
    final map = _asMap(res);
    final result = LoginResult.fromJson(map);
    await _persist(result);
    return result;
  }

  /// `POST /register` — sends an OTP to the user's email.
  Future<String> register(RegistrationData data) async {
    final res = await _api.post('/register', body: data.toJson());
    final map = _asMap(res);
    if (map['status'] != 'success') {
      throw AppException('${map['message'] ?? 'Registration failed'}');
    }
    return '${map['message'] ?? ''}';
  }

  /// `POST /verify-otp` — `{ email, otp_code }`.
  Future<String> verifyOtp(String email, String otpCode) async {
    final res = await _api.post('/verify-otp', body: {
      'email': email,
      'otp_code': otpCode,
    });
    final map = _asMap(res);
    if (map['status'] != 'success') {
      throw AppException('${map['message'] ?? 'Verification failed'}');
    }
    return '${map['message'] ?? ''}';
  }

  /// `GET /me?user_id=` — refreshes credits + profile picture.
  Future<MeInfo> me() async {
    final res = await _api.get('/me', query: _api.authQuery());
    final map = _asMap(res);
    return MeInfo(
      aiCredits: (map['ai_credits'] as num?)?.toInt() ?? 0,
      teamCredits: (map['team_credits'] as num?)?.toInt() ?? 0,
      picture: map['picture'] as String?,
    );
  }

  /// `GET /ai-credits/refresh?user_id=`.
  Future<int> refreshCredits() async {
    final res = await _api.get('/ai-credits/refresh', query: _api.authQuery());
    final map = _asMap(res);
    return (map['ai_credits'] as num?)?.toInt() ?? 0;
  }

  Future<void> logout() => _session.clear();

  Future<void> _persist(LoginResult r) =>
      _session.save(userId: r.userId, token: r.token, role: r.role);

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const AppException('Unexpected server response');
  }
}

/// Lightweight result of `GET /me`.
class MeInfo {
  const MeInfo({
    required this.aiCredits,
    required this.teamCredits,
    this.picture,
  });
  final int aiCredits;
  final int teamCredits;
  final String? picture;
}

/// Common registration payload shared by `/register` and `/google-register`.
class RegistrationData {
  const RegistrationData({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.password,
    required this.phoneNumber,
    required this.address,
    required this.age,
    required this.gender,
    this.entityType = 'Individual',
    this.companyName,
    this.farms,
  });

  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String phoneNumber;
  final String address;
  final int age;
  final String gender;
  final String entityType;
  final String? companyName;
  final List<Map<String, dynamic>>? farms;

  Map<String, dynamic> toJson({bool includePassword = true}) => {
        'first_name': firstName,
        'last_name': lastName,
        if (includePassword) 'email': email,
        if (includePassword) 'password': bcryptSafePassword(password),
        'phone_number': phoneNumber,
        'address': address,
        'entity_type': entityType,
        if (companyName != null) 'company_name': companyName,
        'age': age,
        'gender': gender,
        if (farms != null) 'farms': farms,
      };
}
