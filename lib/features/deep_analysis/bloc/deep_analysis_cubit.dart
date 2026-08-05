import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_exception.dart';
import '../data/analysis_context.dart';
import '../data/deep_analysis_repository.dart';

class DeepAnalysisState extends Equatable {
  const DeepAnalysisState({
    this.context = const AnalysisContext(),
    this.report = '',
    this.thinking = '',
    this.isThinking = false,
    this.streaming = false,
    this.complete = false,
    this.error,
  });

  final AnalysisContext context;

  /// The markdown report as it streams in.
  final String report;

  /// The model's chain of thought, kept apart so the UI can collapse it.
  final String thinking;

  final bool isThinking;
  final bool streaming;

  /// True once a run finished cleanly — distinguishes "done" from "never ran",
  /// which otherwise look identical when the report is empty.
  final bool complete;

  final String? error;

  bool get hasThinking => thinking.trim().isNotEmpty;

  DeepAnalysisState copyWith({
    AnalysisContext? context,
    String? report,
    String? thinking,
    bool? isThinking,
    bool? streaming,
    bool? complete,
    String? error,
  }) => DeepAnalysisState(
    context: context ?? this.context,
    report: report ?? this.report,
    thinking: thinking ?? this.thinking,
    isThinking: isThinking ?? this.isThinking,
    streaming: streaming ?? this.streaming,
    complete: complete ?? this.complete,
    error: error,
  );

  @override
  List<Object?> get props => [
    context,
    report,
    thinking,
    isThinking,
    streaming,
    complete,
    error,
  ];
}

/// Drives the deep diagnosis: holds the farm context and streams the report.
class DeepAnalysisCubit extends Cubit<DeepAnalysisState> {
  DeepAnalysisCubit(this._repo, this._store) : super(const DeepAnalysisState());

  final DeepAnalysisRepository _repo;
  final AnalysisContextStore _store;

  /// Bumped on every run so a superseded stream cannot write over a newer one
  /// after the user re-runs the analysis.
  int _run = 0;

  Future<void> loadContext() async {
    final ctx = await _store.read();
    if (isClosed) return;
    emit(state.copyWith(context: ctx));
  }

  Future<void> updateContext(AnalysisContext ctx) async {
    emit(state.copyWith(context: ctx));
    await _store.write(ctx);
  }

  Future<void> run({
    required int deviceId,
    required Map<String, double> sensors,
    required String lang,
  }) async {
    if (state.streaming) return;

    final run = ++_run;
    emit(
      state.copyWith(
        report: '',
        thinking: '',
        isThinking: false,
        streaming: true,
        complete: false,
        error: null,
      ),
    );

    final report = StringBuffer();
    final thinking = StringBuffer();
    var inThinkTag = false;

    void push({bool? isThinking}) {
      emit(
        state.copyWith(
          report: report.toString(),
          thinking: thinking.toString(),
          isThinking: isThinking,
        ),
      );
    }

    try {
      final weather = await _repo.latestWeather(deviceId);
      if (isClosed || run != _run) return;

      final stream = _repo.diagnose(
        sensors: sensors,
        weather: weather,
        context: state.context,
        lang: lang,
      );

      await for (final token in stream) {
        if (isClosed || run != _run) return;

        if (token.isReasoning) {
          thinking.write(token.text);
          push(isThinking: true);
          continue;
        }

        // Some models wrap their working in <think> tags inside the content
        // channel instead of using a separate one.
        final chunk = token.text;
        if (!inThinkTag && chunk.contains('<think>')) {
          final parts = chunk.split('<think>');
          report.write(parts.first);
          if (parts.length > 1) thinking.write(parts[1]);
          inThinkTag = true;
          push(isThinking: true);
          continue;
        }
        if (inThinkTag) {
          if (chunk.contains('</think>')) {
            final parts = chunk.split('</think>');
            thinking.write(parts.first);
            if (parts.length > 1) report.write(parts[1]);
            inThinkTag = false;
            push(isThinking: false);
          } else {
            thinking.write(chunk);
            push(isThinking: true);
          }
          continue;
        }

        report.write(chunk);
        push(isThinking: false);
      }

      if (isClosed || run != _run) return;
      emit(
        state.copyWith(
          report: report.toString(),
          thinking: thinking.toString(),
          isThinking: false,
          streaming: false,
          complete: true,
        ),
      );
    } on AppException catch (e) {
      _fail(run, report, thinking, e.message);
    } catch (_) {
      _fail(run, report, thinking, 'Deep analysis failed. Please try again.');
    }
  }

  void _fail(
    int run,
    StringBuffer report,
    StringBuffer thinking,
    String error,
  ) {
    if (isClosed || run != _run) return;
    emit(
      state.copyWith(
        report: report.toString(),
        thinking: thinking.toString(),
        isThinking: false,
        streaming: false,
        error: error,
      ),
    );
  }

  void reset() {
    _run++;
    emit(
      DeepAnalysisState(context: state.context),
    );
  }
}
