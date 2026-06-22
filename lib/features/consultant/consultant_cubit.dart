import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/app_exception.dart';
import '../auth/bloc/auth_cubit.dart';
import '../dashboard/bloc/history_cubit.dart' show LoadState;
import 'data/consultant_models.dart';
import 'data/consultant_repository.dart';

class ConsultantState extends Equatable {
  const ConsultantState({
    this.optionsState = LoadState.initial,
    this.options = const ConsultantOptions(),
    this.messages = const [],
    this.sending = false,
    this.error,
  });

  final LoadState optionsState;
  final ConsultantOptions options;
  final List<ChatMessage> messages;
  final bool sending;
  final String? error;

  ConsultantState copyWith({
    LoadState? optionsState,
    ConsultantOptions? options,
    List<ChatMessage>? messages,
    bool? sending,
    String? error,
  }) =>
      ConsultantState(
        optionsState: optionsState ?? this.optionsState,
        options: options ?? this.options,
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        error: error,
      );

  @override
  List<Object?> get props => [optionsState, options, messages, sending, error];
}

/// Drives the async AI consultant: load options, send a question (start +
/// poll), append the answer. The [selection] of attached context is held here
/// and mutated directly by the UI.
class ConsultantCubit extends Cubit<ConsultantState> {
  ConsultantCubit(this._repo, this._auth) : super(const ConsultantState());

  final ConsultantRepository _repo;
  final AuthCubit _auth;

  final ConsultantSelection selection = ConsultantSelection();

  Future<void> loadOptions() async {
    emit(state.copyWith(optionsState: LoadState.loading, error: null));
    try {
      final options = await _repo.getOptions();
      emit(state.copyWith(optionsState: LoadState.loaded, options: options));
    } on AppException catch (e) {
      emit(state.copyWith(optionsState: LoadState.error, error: e.message));
    }
  }

  Future<void> send(String question) async {
    final uid = _auth.state.userId;
    if (uid == null || question.trim().isEmpty || state.sending) return;

    final history = [
      ...state.messages,
      ChatMessage(role: 'user', content: question.trim()),
    ];
    emit(state.copyWith(messages: history, sending: true, error: null));

    try {
      final taskId =
          await _repo.start(userId: uid, history: history, selection: selection);
      final answer = await _poll(taskId);
      emit(state.copyWith(
        messages: [
          ...history,
          ChatMessage(role: 'assistant', content: answer),
        ],
        sending: false,
      ));
      _auth.refreshCredits();
    } on InsufficientCreditsException {
      emit(state.copyWith(sending: false)); // paywall handled globally
    } on AppException catch (e) {
      emit(state.copyWith(sending: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(
          sending: false,
          error: e.toString().replaceFirst('Exception: ', '')));
    }
  }

  /// Polls every 3s up to ~180s, mirroring the web client.
  Future<String> _poll(String taskId) async {
    const maxAttempts = 60;
    for (var i = 0; i < maxAttempts; i++) {
      if (isClosed) return '';
      await Future<void>.delayed(const Duration(seconds: 3));
      if (isClosed) return '';
      final status = await _repo.pollStatus(taskId);
      if (status.isDone) return status.answer ?? '';
      if (status.isFailed) {
        throw AppException(status.error ?? 'The AI task failed.');
      }
    }
    throw const AppException('The AI consultant timed out. Please try again.');
  }
}
