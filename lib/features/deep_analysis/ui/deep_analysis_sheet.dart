import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/localization/app_localizations.dart';
import '../bloc/deep_analysis_cubit.dart';

/// The streaming deep-diagnosis report.
///
/// Opened as a near-full-height sheet rather than a card on the dashboard: the
/// report is a long markdown document with tables, and it would bury the live
/// readings underneath it.
class DeepAnalysisSheet extends StatefulWidget {
  const DeepAnalysisSheet({super.key, required this.cubit, this.onRerun});

  final DeepAnalysisCubit cubit;
  final VoidCallback? onRerun;

  static Future<void> show(
    BuildContext context,
    DeepAnalysisCubit cubit, {
    VoidCallback? onRerun,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: DeepAnalysisSheet(cubit: cubit, onRerun: onRerun),
      ),
    );
  }

  @override
  State<DeepAnalysisSheet> createState() => _DeepAnalysisSheetState();
}

class _DeepAnalysisSheetState extends State<DeepAnalysisSheet> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _followStream() {
    if (!_scroll.hasClients) return;
    // Only follow along if the user hasn't scrolled up to read something —
    // yanking them back to the bottom mid-read is worse than losing the tail.
    final pos = _scroll.position;
    if (pos.maxScrollExtent - pos.pixels > 240) return;
    _scroll.jumpTo(pos.maxScrollExtent);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: BlocConsumer<DeepAnalysisCubit, DeepAnalysisState>(
        listener: (_, _) =>
            WidgetsBinding.instance.addPostFrameCallback((_) => _followStream()),
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.biotech_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('deep_analysis'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (state.report.isNotEmpty && !state.streaming)
                      IconButton(
                        tooltip: context.tr('copy'),
                        icon: const Icon(Icons.copy_all_outlined),
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: state.report),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.tr('copied'))),
                          );
                        },
                      ),
                    if (widget.onRerun != null && !state.streaming)
                      IconButton(
                        tooltip: context.tr('run_again'),
                        icon: const Icon(Icons.refresh),
                        onPressed: widget.onRerun,
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    if (state.hasThinking) _ThinkingPanel(state: state),
                    if (state.error != null) ...[
                      const SizedBox(height: 8),
                      _ErrorBanner(message: state.error!),
                    ],
                    if (state.report.isEmpty && state.streaming)
                      _Waiting(isThinking: state.isThinking)
                    else if (state.report.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      MarkdownBody(data: state.report, selectable: true),
                    ],
                    if (state.streaming && state.report.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const _TypingDot(),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.isThinking});
  final bool isThinking;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            isThinking
                ? context.tr('analysis_thinking')
                : context.tr('analysis_running'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _TypingDot extends StatelessWidget {
  const _TypingDot();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Text(
          context.tr('analysis_running'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// The model's working, collapsed once the report itself starts arriving.
class _ThinkingPanel extends StatelessWidget {
  const _ThinkingPanel({required this.state});
  final DeepAnalysisState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final live = state.isThinking;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('deep-think-$live'),
          initiallyExpanded: live,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(
            Icons.psychology_outlined,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            live ? context.tr('analysis_thinking') : context.tr('reasoning'),
            style: theme.textTheme.labelLarge,
          ),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                state.thinking.trim(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
