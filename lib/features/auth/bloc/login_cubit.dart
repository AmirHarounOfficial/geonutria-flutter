import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_exception.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';
import '../data/google_auth_service.dart';

enum LoginStatus {
  idle,
  submitting,
  success,
  failure,
  googleInProgress,
  googleNeedsOnboarding,
}

class LoginState extends Equatable {
  const LoginState({
    this.status = LoginStatus.idle,
    this.result,
    this.googleOnboarding,
    this.error,
  });

  final LoginStatus status;
  final LoginResult? result;
  final GoogleOnboarding? googleOnboarding;
  final String? error;

  LoginState copyWith({
    LoginStatus? status,
    LoginResult? result,
    GoogleOnboarding? googleOnboarding,
    String? error,
  }) =>
      LoginState(
        status: status ?? this.status,
        result: result ?? this.result,
        googleOnboarding: googleOnboarding ?? this.googleOnboarding,
        error: error,
      );

  @override
  List<Object?> get props => [status, result, googleOnboarding, error];
}

class LoginCubit extends Cubit<LoginState> {
  LoginCubit(this._repo, this._google) : super(const LoginState());

  final AuthRepository _repo;
  final GoogleAuthService _google;

  Future<void> submit(String username, String password) async {
    emit(state.copyWith(status: LoginStatus.submitting, error: null));
    try {
      final result = await _repo.login(username.trim(), password);
      emit(state.copyWith(status: LoginStatus.success, result: result));
    } on AppException catch (e) {
      emit(state.copyWith(status: LoginStatus.failure, error: e.message));
    } catch (_) {
      emit(state.copyWith(
        status: LoginStatus.failure,
        error: 'Login failed. Please try again.',
      ));
    }
  }

  Future<void> googleSignIn() async {
    emit(state.copyWith(status: LoginStatus.googleInProgress, error: null));
    try {
      final accessToken = await _google.signInAccessToken();
      if (accessToken == null) {
        emit(state.copyWith(status: LoginStatus.idle)); // cancelled
        return;
      }
      final outcome = await _repo.googleLogin(accessToken);
      if (outcome.requiresOnboarding) {
        emit(state.copyWith(
          status: LoginStatus.googleNeedsOnboarding,
          googleOnboarding: outcome.onboarding,
        ));
      } else {
        emit(state.copyWith(
          status: LoginStatus.success,
          result: outcome.login,
        ));
      }
    } on AppException catch (e) {
      emit(state.copyWith(status: LoginStatus.failure, error: e.message));
    } catch (_) {
      emit(state.copyWith(
        status: LoginStatus.failure,
        error: 'Google sign-in failed.',
      ));
    }
  }
}
