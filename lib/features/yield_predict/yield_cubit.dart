import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/error/app_exception.dart';
import '../../core/network/api_client.dart';
import '../auth/bloc/auth_cubit.dart';
import '../dashboard/bloc/history_cubit.dart' show LoadState;
import '../deep_analysis/data/analysis_context.dart';

class YieldState extends Equatable {
  const YieldState({
    this.state = LoadState.initial,
    this.aiReport = '',
    this.thinking = '',
    this.isThinking = false,
    this.streaming = false,
    this.error,
  });

  final LoadState state;
  final String aiReport;
  final String thinking;
  final bool isThinking;
  final bool streaming;
  final String? error;

  YieldState copyWith({
    LoadState? state,
    String? aiReport,
    String? thinking,
    bool? isThinking,
    bool? streaming,
    String? error,
  }) =>
      YieldState(
        state: state ?? this.state,
        aiReport: aiReport ?? this.aiReport,
        thinking: thinking ?? this.thinking,
        isThinking: isThinking ?? this.isThinking,
        streaming: streaming ?? this.streaming,
        error: error,
      );

  @override
  List<Object?> get props => [state, aiReport, thinking, isThinking, streaming, error];
}

class YieldCubit extends Cubit<YieldState> {
  YieldCubit(this._api, this._auth) : super(const YieldState());

  final ApiClient _api;
  final AuthCubit _auth;

  Future<void> predict({
    required String crop,
    required int n,
    required int p,
    required int k,
    required int temperature,
    required int humidity,
    required double ph,
    required int rainfall,
    String lang = 'en',
    AnalysisContext? context,
  }) async {
    final uid = _auth.state.userId;
    if (uid == null) return;
    emit(state.copyWith(
      state: LoadState.loading,
      streaming: true,
      isThinking: true,
      aiReport: '',
      thinking: '',
      error: null,
    ));

    final answer = StringBuffer();
    final thinkingBuf = StringBuffer();
    var inThinkTag = false;

    try {
      final payload = {
        'user_id': uid,
        'Crop': crop,
        'Rainfall': rainfall,
        'N': n,
        'P': p,
        'K': k,
        'Temperature': temperature,
        'Humidity': humidity,
        'pH': ph,
        'lang': lang,
        'stream': true,
        if (context != null && !context.isEmpty) 'context': context.toJson(),
      };

      final stream = _api.streamChatTokens(
        '/predict-yield',
        body: payload,
      );

      await for (final token in stream) {
        if (isClosed) return;

        if (token.isReasoning) {
          thinkingBuf.write(token.text);
          emit(state.copyWith(
            thinking: thinkingBuf.toString(),
            isThinking: true,
          ));
          continue;
        }

        var chunk = token.text;
        if (!inThinkTag && chunk.contains('<think>')) {
          final parts = chunk.split('<think>');
          answer.write(parts.first);
          if (parts.length > 1) thinkingBuf.write(parts[1]);
          inThinkTag = true;
          emit(state.copyWith(
            aiReport: answer.toString(),
            thinking: thinkingBuf.toString(),
            isThinking: true,
          ));
          continue;
        }
        if (inThinkTag) {
          if (chunk.contains('</think>')) {
            final parts = chunk.split('</think>');
            thinkingBuf.write(parts.first);
            if (parts.length > 1) answer.write(parts[1]);
            inThinkTag = false;
            emit(state.copyWith(
              aiReport: answer.toString(),
              thinking: thinkingBuf.toString(),
              isThinking: false,
            ));
          } else {
            thinkingBuf.write(chunk);
            emit(state.copyWith(
              thinking: thinkingBuf.toString(),
              isThinking: true,
            ));
          }
          continue;
        }

        answer.write(chunk);
        emit(state.copyWith(
          aiReport: answer.toString(),
          isThinking: false,
        ));
      }

      emit(state.copyWith(
        state: LoadState.loaded,
        streaming: false,
        isThinking: false,
      ));
      _auth.onCreditsSpent(5);
    } on InsufficientCreditsException {
      emit(state.copyWith(state: LoadState.initial, streaming: false));
    } on AppException catch (e) {
      emit(state.copyWith(
        state: LoadState.error,
        streaming: false,
        error: e.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        state: LoadState.error,
        streaming: false,
        error: 'Yield prediction request failed: $e',
      ));
    }
  }

  void resetAnalysis() {
    emit(const YieldState());
  }
}

