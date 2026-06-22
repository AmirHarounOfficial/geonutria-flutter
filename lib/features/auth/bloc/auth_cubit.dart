import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/storage/secure_session.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.userId,
    this.role,
    this.aiCredits = 0,
    this.teamCredits = 0,
    this.picture,
  });

  final AuthStatus status;
  final int? userId;
  final String? role;
  final int aiCredits;
  final int teamCredits;
  final String? picture;

  bool get isAdmin => role == 'Admin';

  AuthState copyWith({
    AuthStatus? status,
    int? userId,
    String? role,
    int? aiCredits,
    int? teamCredits,
    String? picture,
  }) =>
      AuthState(
        status: status ?? this.status,
        userId: userId ?? this.userId,
        role: role ?? this.role,
        aiCredits: aiCredits ?? this.aiCredits,
        teamCredits: teamCredits ?? this.teamCredits,
        picture: picture ?? this.picture,
      );

  @override
  List<Object?> get props =>
      [status, userId, role, aiCredits, teamCredits, picture];
}

/// Holds the global session + live credit balances. Mirrors the web app's
/// top-level auth state and `credit-deducted` / `credits-depleted` events.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repo, this._session) : super(const AuthState());

  final AuthRepository _repo;
  final SecureSession _session;

  /// Restore any persisted session on startup, then refresh credits. Any
  /// storage failure falls back to the unauthenticated state so the app always
  /// reaches the login screen rather than hanging on the splash.
  Future<void> bootstrap() async {
    try {
      await _session.load();
    } catch (_) {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
      return;
    }
    if (!_session.isLoggedIn) {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
      return;
    }
    String? role;
    try {
      role = await _session.role;
    } catch (_) {
      role = null;
    }
    emit(state.copyWith(
      status: AuthStatus.authenticated,
      userId: _session.userId,
      role: role,
    ));
    await refreshCredits();
  }

  /// Forces the unauthenticated terminal state (used if bootstrap throws).
  void forceUnauthenticated() {
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  void onAuthenticated(LoginResult r) {
    emit(state.copyWith(
      status: AuthStatus.authenticated,
      userId: r.userId,
      role: r.role,
      aiCredits: r.aiCredits,
      teamCredits: r.teamCredits,
    ));
  }

  Future<void> refreshCredits() async {
    try {
      final me = await _repo.me();
      emit(state.copyWith(
        aiCredits: me.aiCredits,
        teamCredits: me.teamCredits,
        picture: me.picture,
      ));
    } catch (_) {
      // Non-fatal; keep last known balances.
    }
  }

  /// Optimistically decrement after a paid feature succeeds (web parity).
  void onCreditsSpent([int amount = 5]) {
    final next = (state.aiCredits - amount).clamp(0, 1 << 31);
    emit(state.copyWith(aiCredits: next));
  }

  Future<void> logout() async {
    await _repo.logout();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }
}
