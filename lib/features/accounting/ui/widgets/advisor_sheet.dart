import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../bloc/accounting_cubit.dart';
import '../../bloc/advisor_cubit.dart';

/// The streaming AI financial analysis of the accounting tree.
class AdvisorSheet extends StatefulWidget {
  const AdvisorSheet({
    super.key,
    required this.advisor,
    required this.accounting,
  });

  final AdvisorCubit advisor;
  final AccountingCubit accounting;

  static Future<void> show(
    BuildContext context, {
    required AdvisorCubit advisor,
    required AccountingCubit accounting,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider.value(value: advisor),
          BlocProvider.value(value: accounting),
        ],
        child: AdvisorSheet(advisor: advisor, accounting: accounting),
      ),
    );
  }

  @override
  State<AdvisorSheet> createState() => _AdvisorSheetState();
}

class _AdvisorSheetState extends State<AdvisorSheet> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.advisor.loadHistory();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _follow() {
    if (!_scroll.hasClients) return;
    final pos = _scroll.position;
    if (pos.maxScrollExtent - pos.pixels > 240) return;
    _scroll.jumpTo(pos.maxScrollExtent);
  }

  void _analyze() {
    final acc = widget.accounting.state;
    widget.advisor.analyze(
      fiscalYear: acc.year,
      treeData: acc.treeData,
      totalRevenue: acc.totalRevenue,
      totalExpenses: acc.totalExpenses,
      netProfit: acc.netProfit,
      lang: context.locale.languageCode == 'ar' ? 'ar' : 'en',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FractionallySizedBox(
      heightFactor: 0.92,
      child: BlocConsumer<AdvisorCubit, AdvisorState>(
        listener: (_, _) =>
            WidgetsBinding.instance.addPostFrameCallback((_) => _follow()),
        builder: (context, state) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.insights_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('ai_financial_advisor'),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (state.report.isNotEmpty && !state.streaming)
                      IconButton(
                        tooltip: state.saved
                            ? context.tr('saved')
                            : context.tr('save_report'),
                        icon: Icon(
                          state.saved
                              ? Icons.bookmark
                              : Icons.bookmark_border,
                        ),
                        onPressed: state.saved
                            ? null
                            : () => widget.advisor.save(
                                fiscalYear: widget.accounting.state.year,
                              ),
                      ),
                    if (state.history.isNotEmpty)
                      IconButton(
                        tooltip: context.tr('report_history'),
                        icon: const Icon(Icons.history),
                        onPressed: () => _showHistory(context, state),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    for (final len in AdvisorLength.all) ...[
                      ChoiceChip(
                        label: Text(context.tr('advisor_len_$len')),
                        selected: state.length == len,
                        onSelected: state.streaming
                            ? null
                            : (_) => widget.advisor.setLength(len),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    if (state.hasThinking) _ThinkingPanel(state: state),
                    if (state.error != null) ...[
                      const SizedBox(height: 8),
                      _ErrorBanner(message: state.error!),
                    ],
                    if (state.report.isEmpty && state.streaming)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (state.report.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      MarkdownBody(data: state.report, selectable: true),
                    ] else
                      _Intro(onAnalyze: _analyze),
                  ],
                ),
              ),
              if (state.report.isNotEmpty || state.streaming)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: state.streaming ? null : _analyze,
                      icon: state.streaming
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(
                        state.streaming
                            ? context.tr('analysis_running')
                            : context.tr('run_again'),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showHistory(BuildContext context, AdvisorState state) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              context.tr('report_history'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final r in state.history)
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text('${context.tr('fiscal_year')} ${r.fiscalYear}'),
              subtitle: Text(
                (r.createdAt ?? '').split('T').first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                widget.advisor.open(r);
                Navigator.of(sheetContext).pop();
              },
            ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro({required this.onAnalyze});
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(
            Icons.insights_outlined,
            size: 44,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(
            context.tr('advisor_intro'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAnalyze,
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: Text(context.tr('analyze_finances')),
          ),
        ],
      ),
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

class _ThinkingPanel extends StatelessWidget {
  const _ThinkingPanel({required this.state});
  final AdvisorState state;

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
          key: ValueKey('advisor-think-$live'),
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
