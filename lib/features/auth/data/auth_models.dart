import 'package:equatable/equatable.dart';

/// Result of a successful `/login`, `/google-login` (existing user) or
/// `/google-register` call.
class LoginResult extends Equatable {
  const LoginResult({
    required this.token,
    required this.userId,
    required this.aiCredits,
    required this.teamCredits,
    this.role,
    this.locale,
  });

  final String token;
  final int userId;
  final int aiCredits;
  final int teamCredits;
  final String? role;
  final String? locale;

  factory LoginResult.fromJson(Map<String, dynamic> j) => LoginResult(
        token: '${j['token'] ?? ''}',
        userId: (j['user_id'] as num).toInt(),
        aiCredits: (j['ai_credits'] as num?)?.toInt() ?? 0,
        teamCredits: (j['team_credits'] as num?)?.toInt() ?? 0,
        role: j['role'] as String?,
        locale: j['locale'] as String?,
      );

  @override
  List<Object?> get props => [token, userId, aiCredits, teamCredits, role];
}

/// Returned by `/google-login` when the Google account is new and the backend
/// asks the client to complete onboarding (`status == requires_onboarding`).
class GoogleOnboarding extends Equatable {
  const GoogleOnboarding({
    required this.email,
    required this.givenName,
    required this.familyName,
    required this.picture,
    required this.googleToken,
    this.locale,
  });

  final String email;
  final String givenName;
  final String familyName;
  final String picture;
  final String googleToken;
  final String? locale;

  factory GoogleOnboarding.fromJson(Map<String, dynamic> j) => GoogleOnboarding(
        email: '${j['email'] ?? ''}',
        givenName: '${j['given_name'] ?? ''}',
        familyName: '${j['family_name'] ?? ''}',
        picture: '${j['picture'] ?? ''}',
        googleToken: '${j['google_token'] ?? ''}',
        locale: j['locale'] as String?,
      );

  @override
  List<Object?> get props => [email, googleToken];
}

/// Wrapper for `/google-login`, which either logs in or requests onboarding.
class GoogleLoginOutcome {
  GoogleLoginOutcome.loggedIn(this.login) : onboarding = null;
  GoogleLoginOutcome.needsOnboarding(this.onboarding) : login = null;

  final LoginResult? login;
  final GoogleOnboarding? onboarding;

  bool get requiresOnboarding => onboarding != null;
}
