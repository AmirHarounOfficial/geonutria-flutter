import 'dart:convert';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/error/app_exception.dart';
import '../../core/network/api_client.dart';
import '../auth/bloc/auth_cubit.dart';
import '../dashboard/bloc/history_cubit.dart' show LoadState;
import '../deep_analysis/data/analysis_context.dart';

class CropAdvisorState extends Equatable {
  const CropAdvisorState({
    this.soilState = LoadState.initial,
    this.soilType = '',
    this.soilStreamContent = '',
    this.soilThinkingContent = '',
    this.isSoilThinking = false,
    this.isSoilComplete = false,
    this.recState = LoadState.initial,
    this.aiReport = '',
    this.thinking = '',
    this.isThinking = false,
    this.streaming = false,
    this.error,
  });

  final LoadState soilState;
  final String soilType;
  final String soilStreamContent;
  final String soilThinkingContent;
  final bool isSoilThinking;
  final bool isSoilComplete;

  final LoadState recState;
  final String aiReport;
  final String thinking;
  final bool isThinking;
  final bool streaming;

  final String? error;

  CropAdvisorState copyWith({
    LoadState? soilState,
    String? soilType,
    String? soilStreamContent,
    String? soilThinkingContent,
    bool? isSoilThinking,
    bool? isSoilComplete,
    LoadState? recState,
    String? aiReport,
    String? thinking,
    bool? isThinking,
    bool? streaming,
    String? error,
  }) =>
      CropAdvisorState(
        soilState: soilState ?? this.soilState,
        soilType: soilType ?? this.soilType,
        soilStreamContent: soilStreamContent ?? this.soilStreamContent,
        soilThinkingContent: soilThinkingContent ?? this.soilThinkingContent,
        isSoilThinking: isSoilThinking ?? this.isSoilThinking,
        isSoilComplete: isSoilComplete ?? this.isSoilComplete,
        recState: recState ?? this.recState,
        aiReport: aiReport ?? this.aiReport,
        thinking: thinking ?? this.thinking,
        isThinking: isThinking ?? this.isThinking,
        streaming: streaming ?? this.streaming,
        error: error,
      );

  @override
  List<Object?> get props => [
        soilState,
        soilType,
        soilStreamContent,
        soilThinkingContent,
        isSoilThinking,
        isSoilComplete,
        recState,
        aiReport,
        thinking,
        isThinking,
        streaming,
        error,
      ];
}

class CropAdvisorCubit extends Cubit<CropAdvisorState> {
  CropAdvisorCubit(this._api, this._auth) : super(const CropAdvisorState());

  final ApiClient _api;
  final AuthCubit _auth;

  Future<void> classifySoil(XFile file, {String lang = 'en'}) async {
    final uid = _auth.state.userId;
    if (uid == null) return;

    emit(state.copyWith(
      soilState: LoadState.loading,
      soilStreamContent: '',
      soilThinkingContent: '',
      isSoilThinking: true,
      isSoilComplete: false,
      error: null,
    ));

    final cleanBuf = StringBuffer();
    final thinkingBuf = StringBuffer();
    var inThinkTag = false;

    try {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(Uint8List.fromList(bytes));

      final payload = {
        'image_base64': base64Image,
        'lang': lang,
        'stream': true,
        'user_id': uid,
      };

      final stream = _api.streamChatTokens(
        '/classify-soil',
        body: payload,
      );

      await for (final token in stream) {
        if (isClosed) return;

        if (token.isReasoning) {
          thinkingBuf.write(token.text);
          emit(state.copyWith(
            soilThinkingContent: thinkingBuf.toString(),
            isSoilThinking: true,
          ));
          continue;
        }

        var chunk = token.text;
        if (!inThinkTag && chunk.contains('<think>')) {
          final parts = chunk.split('<think>');
          cleanBuf.write(parts.first);
          if (parts.length > 1) thinkingBuf.write(parts[1]);
          inThinkTag = true;
          emit(state.copyWith(
            soilStreamContent: cleanBuf.toString(),
            soilThinkingContent: thinkingBuf.toString(),
            isSoilThinking: true,
          ));
          continue;
        }
        if (inThinkTag) {
          if (chunk.contains('</think>')) {
            final parts = chunk.split('</think>');
            thinkingBuf.write(parts.first);
            if (parts.length > 1) cleanBuf.write(parts[1]);
            inThinkTag = false;
            emit(state.copyWith(
              soilStreamContent: cleanBuf.toString(),
              soilThinkingContent: thinkingBuf.toString(),
              isSoilThinking: false,
            ));
          } else {
            thinkingBuf.write(chunk);
            emit(state.copyWith(
              soilThinkingContent: thinkingBuf.toString(),
              isSoilThinking: true,
            ));
          }
          continue;
        }

        cleanBuf.write(chunk);
        emit(state.copyWith(
          soilStreamContent: cleanBuf.toString(),
          isSoilThinking: false,
        ));
      }

      final detectedSoil = cleanBuf.toString().trim();
      final extractedType = detectedSoil.length > 50
          ? detectedSoil.substring(0, 50).trim()
          : detectedSoil;

      emit(state.copyWith(
        soilState: LoadState.loaded,
        soilType: extractedType,
        isSoilThinking: false,
        isSoilComplete: true,
      ));

      _auth.onCreditsSpent(5);
    } on InsufficientCreditsException {
      emit(state.copyWith(soilState: LoadState.initial));
    } on AppException catch (e) {
      emit(state.copyWith(soilState: LoadState.error, error: e.message));
    } catch (e) {
      emit(state.copyWith(
          soilState: LoadState.error, error: 'Soil classification failed: $e'));
    }
  }

  void clearSoil() {
    emit(state.copyWith(
      soilState: LoadState.initial,
      soilType: '',
      soilStreamContent: '',
      soilThinkingContent: '',
      isSoilThinking: false,
      isSoilComplete: false,
    ));
  }

  Future<void> recommend({
    required double n,
    required double p,
    required double k,
    required double temperature,
    required double humidity,
    required double ph,
    required double rainfall,
    required String soilType,
    String lang = 'en',
    AnalysisContext? context,
  }) async {
    final uid = _auth.state.userId;
    if (uid == null) return;

    emit(state.copyWith(
      recState: LoadState.loading,
      streaming: true,
      isThinking: true,
      aiReport: '',
      thinking: '',
      error: null,
    ));

    final answerBuf = StringBuffer();
    final thinkingBuf = StringBuffer();
    var inThinkTag = false;

    try {
      final payload = {
        'user_id': uid,
        'N': n,
        'P': p,
        'K': k,
        'temperature': temperature,
        'humidity': humidity,
        'ph': ph,
        'rainfall': rainfall.toInt(),
        'soil_type': soilType.isNotEmpty ? soilType : 'Not specified',
        'lang': lang,
        'stream': true,
        if (context != null && !context.isEmpty) 'context': context.toJson(),
      };

      final stream = _api.streamChatTokens(
        '/recommend-crops',
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
          answerBuf.write(parts.first);
          if (parts.length > 1) thinkingBuf.write(parts[1]);
          inThinkTag = true;
          emit(state.copyWith(
            aiReport: answerBuf.toString(),
            thinking: thinkingBuf.toString(),
            isThinking: true,
          ));
          continue;
        }
        if (inThinkTag) {
          if (chunk.contains('</think>')) {
            final parts = chunk.split('</think>');
            thinkingBuf.write(parts.first);
            if (parts.length > 1) answerBuf.write(parts[1]);
            inThinkTag = false;
            emit(state.copyWith(
              aiReport: answerBuf.toString(),
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

        answerBuf.write(chunk);
        emit(state.copyWith(
          aiReport: answerBuf.toString(),
          isThinking: false,
        ));
      }

      emit(state.copyWith(
        recState: LoadState.loaded,
        streaming: false,
        isThinking: false,
      ));

      _auth.onCreditsSpent(5);
    } on InsufficientCreditsException {
      emit(state.copyWith(recState: LoadState.initial, streaming: false));
    } on AppException catch (e) {
      emit(state.copyWith(
        recState: LoadState.error,
        streaming: false,
        error: e.message,
      ));
    } catch (e) {
      emit(state.copyWith(
        recState: LoadState.error,
        streaming: false,
        error: 'Recommendation request failed: $e',
      ));
    }
  }

  void resetAnalysis() {
    emit(state.copyWith(
      recState: LoadState.initial,
      aiReport: '',
      thinking: '',
      isThinking: false,
      streaming: false,
      error: null,
    ));
  }
}
