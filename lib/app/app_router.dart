import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_logo.dart';
import '../features/auth/bloc/auth_cubit.dart';
import '../features/auth/ui/login_screen.dart';
import '../features/shell/home_shell.dart';

/// Builds the app router, gating routes on [AuthCubit] state. While the session
/// is being restored ([AuthStatus.unknown]) a splash is shown.
GoRouter buildRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _CubitStream(authCubit.stream),
    redirect: (context, state) {
      final status = authCubit.state.status;
      final loc = state.matchedLocation;
      if (status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }
      final loggedIn = status == AuthStatus.authenticated;
      if (!loggedIn) return loc == '/login' ? null : '/login';
      if (loc == '/login' || loc == '/splash' || loc == '/') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _Splash()),
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeShell()),
    ],
  );
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppLogo(size: 96),
            const SizedBox(height: 20),
            const Text(
              'GeoNutria',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bridges a Bloc/Cubit stream to a [Listenable] for GoRouter refresh.
class _CubitStream extends ChangeNotifier {
  _CubitStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
