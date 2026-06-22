import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/env.dart';

/// Wraps Google Sign-In and returns the OAuth **access token** that the backend
/// (`/google-login`, `/google-register`) uses as a Bearer to fetch the user's
/// Google profile. Returns null if the user cancels.
class GoogleAuthService {
  GoogleAuthService()
      : _googleSignIn = GoogleSignIn(
          scopes: const ['email', 'profile'],
          serverClientId: Env.googleServerClientId.isEmpty
              ? null
              : Env.googleServerClientId,
        );

  final GoogleSignIn _googleSignIn;

  bool get isConfigured => Env.googleServerClientId.isNotEmpty;

  Future<String?> signInAccessToken() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null; // cancelled
    final auth = await account.authentication;
    return auth.accessToken;
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
