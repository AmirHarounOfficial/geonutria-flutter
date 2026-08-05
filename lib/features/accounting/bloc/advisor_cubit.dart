import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_exception.dart';
import '../data/accounting_models.dart';
import '../data/accounting_repository.dart';

/// How long a report the user asked for. Sent verbatim — the backend maps
/// these to word-count constraints in the prompt.
class AdvisorLength {
  const AdvisorLength._();
  static const short = 'short';
  static const medium = 'medium';
  static const full = 'full';
  static const all = [short, medium, full];
}

class AdvisorState extends Equatable {
  const AdvisorState({
    this.report = '',
    this.thinking = '',
    this.isThinking = false,
    this.streaming = false,
    this.complete = false,
    this.length = AdvisorLength.medium,
    this.saved = false,
    this.history = const [],
    this.error,
  });

  final String report;
  final String thinking;
  final bool isThinking;
  final bool streaming;
  final bool complete;
  final String length;

  /// True once this report has been written to the user's report history, so
  /// the save action can't silently store the same analysis twice.
  final bool saved;

  final List<FinancialReport> history;
  final String? error;

  bool get hasThinking => thinking.trim().isNotEmpty;

  AdvisorState copyWith({
    String? report,
    String? thinking,
    bool? isThinking,
    bool? streaming,
    bool? complete,
    String? length,
    bool? saved,
    List<FinancialReport>? history,
    String? error,
  }) => AdvisorState(
    report: report ?? this.report,
    thinking: thinking ?? this.thinking,
    isThinking: isThinking ?? this.isThinking,
    streaming: streaming ?? this.streaming,
    complete: complete ?? this.complete,
    length: length ?? this.length,
    saved: saved ?? this.saved,
    history: history ?? this.history,
    error: error,
  );

  @override
  List<Object?> get props => [
    report,
    thinking,
    isThinking,
    streaming,
    complete,
    length,
    saved,
    history,
    error,
  ];
}

/// Streams the AI financial analysis of the accounting tree.
class AdvisorCubit extends Cubit<AdvisorState> {
  AdvisorCubit(this._repo) : super(const AdvisorState());

  final AccountingRepository _repo;

  int _run = 0;

  void setLength(String length) => emit(state.copyWith(length: length));

  Future<void> analyze({
    required int fiscalYear,
    required List<Map<String, dynamic>> treeData,
    required double totalRevenue,
    required double totalExpenses,
    required double netProfit,
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
        saved: false,
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
      final stream = _repo.advise(
        fiscalYear: fiscalYear,
        treeData: treeData,
        totalRevenue: totalRevenue,
        totalExpenses: totalExpenses,
        netProfit: netProfit,
        lang: lang,
        length: state.length,
      );

      await for (final token in stream) {
        if (isClosed || run != _run) return;

        if (token.isReasoning) {
          thinking.write(token.text);
          push(isThinking: true);
          continue;
        }

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
      _fail(run, report, thinking, 'Analysis failed. Please try again.');
    }
  }

  void _fail(int run, StringBuffer report, StringBuffer thinking, String msg) {
    if (isClosed || run != _run) return;
    emit(
      state.copyWith(
        report: report.toString(),
        thinking: thinking.toString(),
        isThinking: false,
        streaming: false,
        error: msg,
      ),
    );
  }

  Future<void> save({required int fiscalYear}) async {
    if (state.report.isEmpty || state.saved || state.streaming) return;
    try {
      await _repo.saveReport(
        fiscalYear: fiscalYear,
        content: state.report,
        lengthPreference: state.length,
      );
      if (isClosed) return;
      emit(state.copyWith(saved: true));
      await loadHistory();
    } on AppException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e.message));
    }
  }

  Future<void> loadHistory() async {
    try {
      final reports = await _repo.reports();
      if (isClosed) return;
      emit(state.copyWith(history: reports));
    } on AppException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(error: e.message));
    }
  }

  /// Shows a stored report in place of the live one.
  void open(FinancialReport report) {
    _run++;
    emit(
      state.copyWith(
        report: report.content,
        thinking: '',
        isThinking: false,
        streaming: false,
        complete: true,
        saved: true,
      ),
    );
  }
}
