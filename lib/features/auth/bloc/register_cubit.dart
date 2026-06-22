import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_exception.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

enum RegisterStatus { idle, submitting, awaitingOtp, verifying, success, failure }

class RegisterState extends Equatable {
  const RegisterState({
    this.status = RegisterStatus.idle,
    this.email,
    this.password,
    this.message,
    this.result,
    this.error,
  });

  final RegisterStatus status;
  final String? email; // captured for OTP + auto-login
  final String? password;
  final String? message;
  final LoginResult? result;
  final String? error;

  RegisterState copyWith({
    RegisterStatus? status,
    String? email,
    String? password,
    String? message,
    LoginResult? result,
    String? error,
  }) =>
      RegisterState(
        status: status ?? this.status,
        email: email ?? this.email,
        password: password ?? this.password,
        message: message,
        result: result ?? this.result,
        error: error,
      );

  @override
  List<Object?> get props =>
      [status, email, password, message, result, error];
}

/// Drives the standard registration (register -> OTP -> auto-login) and the
/// Google completion path (google-register -> session, no OTP).
class RegisterCubit extends Cubit<RegisterState> {
  RegisterCubit(this._repo) : super(const RegisterState());

  final AuthRepository _repo;

  /// Standard sign-up. On success the backend emails an OTP; the UI then moves
  /// to the verification step.
  Future<void> register(RegistrationData data) async {
    emit(state.copyWith(status: RegisterStatus.submitting, error: null));
    try {
      final msg = await _repo.register(data);
      emit(state.copyWith(
        status: RegisterStatus.awaitingOtp,
        email: data.email,
        password: data.password,
        message: msg,
      ));
    } on AppException catch (e) {
      emit(state.copyWith(status: RegisterStatus.failure, error: e.message));
    }
  }

  /// Verify the OTP, then log in with the captured credentials.
  Future<void> verifyOtpAndLogin(String otpCode) async {
    final email = state.email;
    final password = state.password;
    if (email == null || password == null) return;
    emit(state.copyWith(status: RegisterStatus.verifying, error: null));
    try {
      await _repo.verifyOtp(email, otpCode);
      final result = await _repo.login(email, password);
      emit(state.copyWith(status: RegisterStatus.success, result: result));
    } on AppException catch (e) {
      emit(state.copyWith(status: RegisterStatus.awaitingOtp, error: e.message));
    }
  }

  /// Complete Google sign-up. Logs in directly (account auto-verified).
  Future<void> googleRegister(String googleToken, RegistrationData data) async {
    emit(state.copyWith(status: RegisterStatus.submitting, error: null));
    try {
      final result =
          await _repo.googleRegister(googleToken: googleToken, data: data);
      emit(state.copyWith(status: RegisterStatus.success, result: result));
    } on AppException catch (e) {
      emit(state.copyWith(status: RegisterStatus.failure, error: e.message));
    }
  }
}
