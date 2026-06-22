import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'core/network/api_client.dart';
import 'core/network/paywall_notifier.dart';
import 'core/settings/settings_cubit.dart';
import 'core/storage/secure_session.dart';
import 'features/auth/bloc/auth_cubit.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/google_auth_service.dart';

Future<void> main() async {
  // Surface build/runtime errors on-screen instead of a blank page.
  ErrorWidget.builder = (details) => _StartupError(message: '${details.exception}');

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // --- Composition root ---
    final session = SecureSession();
    final paywall = PaywallNotifier();
    final api = ApiClient(session, paywall: paywall);
    final authRepo = AuthRepository(api, session);
    final googleAuth = GoogleAuthService();

    final settingsCubit = SettingsCubit(session);
    final authCubit = AuthCubit(authRepo, session);

    // Render the UI immediately (the router shows the splash while auth status
    // is unknown). Bootstrap runs AFTER first paint so nothing — not even a
    // hanging secure-storage read on some devices — can freeze the launch
    // screen forever.
    runApp(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider.value(value: session),
          RepositoryProvider.value(value: paywall),
          RepositoryProvider.value(value: api),
          RepositoryProvider.value(value: authRepo),
          RepositoryProvider.value(value: googleAuth),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: settingsCubit),
            BlocProvider.value(value: authCubit),
          ],
          child: const GeoNutriaApp(),
        ),
      ),
    );

    unawaited(_bootstrap(settingsCubit, authCubit));
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}

/// Loads persisted settings + session after first paint. Each step is bounded
/// by a timeout so a misbehaving platform channel can never wedge startup;
/// auth always resolves to a terminal state (login or home).
Future<void> _bootstrap(SettingsCubit settings, AuthCubit auth) async {
  try {
    await settings.load().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('settings load failed/timed out: $e');
  }
  try {
    await auth.bootstrap().timeout(const Duration(seconds: 8));
  } catch (e) {
    debugPrint('auth bootstrap failed/timed out: $e');
    auth.forceUnauthenticated();
  }
}

/// Minimal full-screen error view shown if the widget tree fails to build,
/// so the user sees the cause rather than a blank page.
class _StartupError extends StatelessWidget {
  const _StartupError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        color: const Color(0xFF1B263B),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong starting GeoNutria',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
