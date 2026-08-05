import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/status_views.dart';
import '../bloc/accounting_cubit.dart';
import '../bloc/advisor_cubit.dart';
import '../data/accounting_models.dart';
import '../data/accounting_repository.dart';
import 'widgets/advisor_sheet.dart';
import 'widgets/node_editor_sheet.dart';

/// Farm accounting: the revenue/expense tree for a fiscal year, plus the AI
/// financial advisor that reads it.
class AccountingScreen extends StatelessWidget {
  const AccountingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AccountingRepository(context.read<ApiClient>());
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              AccountingCubit(repo, year: DateTime.now().year)..load(),
        ),
        BlocProvider(create: (_) => AdvisorCubit(repo)),
      ],
      child: _AccountingView(repo: repo),
    );
  }
}

/// A row of the flattened tree: the node plus how deep it sits.
class _Row {
  const _Row(this.node, this.depth, this.hasChildren);
  final AccountingNode node;
  final int depth;
  final bool hasChildren;
}

class _AccountingView extends StatelessWidget {
  const _AccountingView({required this.repo});

  final AccountingRepository repo;

  /// Walks the tree into a flat list, skipping anything under a collapsed
  /// parent. A ListView over this is far cheaper than nested Columns and keeps
  /// scrolling smooth on a long ledger.
  List<_Row> _flatten(AccountingState state, List<AccountingNode> roots) {
    final rows = <_Row>[];
    void walk(AccountingNode node, int depth) {
      final children =
          state.childrenOf[node.id] ?? const <AccountingNode>[];
      rows.add(_Row(node, depth, children.isNotEmpty));
      if (!node.isExpanded) return;
      for (final child in children) {
        walk(child, depth + 1);
      }
    }

    for (final r in roots) {
      walk(r, 0);
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AccountingCubit, AccountingState>(
      listenWhen: (a, b) => a.error != b.error && b.error != null,
      listener: (ctx, state) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text(state.error!)),
        );
        ctx.read<AccountingCubit>().clearError();
      },
      builder: (context, state) {
        final cubit = context.read<AccountingCubit>();
        return Scaffold(
          body: Column(
            children: [
              _YearBar(state: state),
              if (state.status == AccountingStatus.loading)
                const Expanded(child: LoadingView())
              else if (state.status == AccountingStatus.error)
                Expanded(
                  child: ErrorView(
                    message: state.error ?? context.tr('error_generic'),
                    onRetry: cubit.load,
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => cubit.load(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      children: [
                        _SummaryCard(state: state),
                        const SizedBox(height: 16),
                        _Section(
                          title: context.tr('revenues'),
                          icon: Icons.trending_up,
                          color: Colors.green,
                          total: state.totalRevenue,
                          rows: _flatten(state, state.revenueRoots),
                          nodeType: NodeType.revenue,
                          repo: repo,
                          state: state,
                        ),
                        const SizedBox(height: 20),
                        _Section(
                          title: context.tr('expenses'),
                          icon: Icons.trending_down,
                          color: Theme.of(context).colorScheme.error,
                          total: state.totalExpenses,
                          rows: _flatten(state, state.expenseRoots),
                          nodeType: NodeType.expense,
                          repo: repo,
                          state: state,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          floatingActionButton: state.isEmpty
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => AdvisorSheet.show(
                    context,
                    advisor: context.read<AdvisorCubit>(),
                    accounting: cubit,
                  ),
                  icon: const Icon(Icons.insights_outlined),
                  label: Text(context.tr('ai_advisor')),
                ),
        );
      },
    );
  }
}

class _YearBar extends StatelessWidget {
  const _YearBar({required this.state});
  final AccountingState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().year;
    // A ledger is kept for past seasons and planned one ahead; anything beyond
    // that is noise in a dropdown.
    final years = [for (var y = now + 1; y >= now - 5; y--) y];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: years.contains(state.year) ? state.year : now,
              decoration: InputDecoration(
                labelText: context.tr('fiscal_year'),
                prefixIcon: const Icon(Icons.calendar_month_outlined),
                isDense: true,
              ),
              items: [
                for (final y in years)
                  DropdownMenuItem(value: y, child: Text('$y')),
              ],
              onChanged: (v) {
                if (v != null) context.read<AccountingCubit>().load(year: v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Revenue, expenses and the bottom line for the selected year.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.state});
  final AccountingState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final net = state.netProfit;
    final netColor = net > 0
        ? Colors.green
        : net < 0
        ? theme.colorScheme.error
        : theme.colorScheme.outline;
    final verdict = net > 0
        ? context.tr('profit')
        : net < 0
        ? context.tr('loss')
        : context.tr('breakeven');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _Figure(
                    label: context.tr('revenues'),
                    value: state.totalRevenue,
                    color: Colors.green,
                  ),
                ),
                Container(
                  width: 1,
                  height: 34,
                  color: theme.colorScheme.outlineVariant,
                ),
                Expanded(
                  child: _Figure(
                    label: context.tr('expenses'),
                    value: state.totalExpenses,
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  net > 0
                      ? Icons.arrow_upward
                      : net < 0
                      ? Icons.arrow_downward
                      : Icons.remove,
                  size: 18,
                  color: netColor,
                ),
                const SizedBox(width: 6),
                Text(
                  '${context.tr('net_profit')}: ',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  formatMoney(context, net),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: netColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '· $verdict',
                  style: theme.textTheme.labelMedium?.copyWith(color: netColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          child: Text(
            formatMoney(context, value),
            style: theme.textTheme.titleMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.total,
    required this.rows,
    required this.nodeType,
    required this.repo,
    required this.state,
  });

  final String title;
  final IconData icon;
  final Color color;
  final double total;
  final List<_Row> rows;
  final String nodeType;
  final AccountingRepository repo;
  final AccountingState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<AccountingCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title, style: theme.textTheme.titleSmall),
            const Spacer(),
            Text(
              formatMoney(context, total),
              style: theme.textTheme.titleSmall?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              context.tr('no_lines_yet'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          )
        else
          for (final row in rows)
            _NodeRow(row: row, repo: repo, state: state, accent: color),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => cubit.addNode(nodeType: nodeType),
          icon: const Icon(Icons.add, size: 18),
          label: Text(context.tr('add_line')),
        ),
      ],
    );
  }
}

class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.row,
    required this.repo,
    required this.state,
    required this.accent,
  });

  final _Row row;
  final AccountingRepository repo;
  final AccountingState state;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<AccountingCubit>();
    final node = row.node;
    final lang = context.locale.languageCode;
    final name = node.displayName(lang);
    final total = state.totals[node.id] ?? 0;

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: row.depth * 16.0,
        bottom: 6,
      ),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => NodeEditorSheet.show(
            context,
            node: node,
            cubit: cubit,
            repo: repo,
            hasChildren: row.hasChildren,
            computedTotal: total,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 4,
              end: 12,
              top: 6,
              bottom: 6,
            ),
            child: Row(
              children: [
                if (row.hasChildren)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      node.isExpanded ? Icons.expand_more : Icons.chevron_right,
                      size: 20,
                    ),
                    onPressed: () => cubit.toggleExpanded(node.id),
                  )
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? context.tr('unnamed') : name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: row.hasChildren
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontStyle: name.isEmpty ? FontStyle.italic : null,
                          color: name.isEmpty
                              ? theme.colorScheme.outline
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (node.unitPrice != null && node.quantity != null)
                        Text(
                          '${_num(node.unitPrice!)} × ${_num(node.quantity!)}'
                          '${node.frequency != null ? ' · ${context.tr('freq_${node.frequency}')}' : ''}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formatMoney(context, total),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: context.tr('add_sub_line'),
                  icon: const Icon(Icons.subdirectory_arrow_right, size: 18),
                  onPressed: () => cubit.addNode(
                    nodeType: node.nodeType,
                    parentId: node.id,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// Money with thousands separators in the active locale, suffixed with the
/// currency the backend reports in.
String formatMoney(BuildContext context, double value) {
  final f = NumberFormat.decimalPatternDigits(
    locale: context.locale.languageCode,
    decimalDigits: value == value.roundToDouble() ? 0 : 2,
  );
  return '${f.format(value)} ${context.tr('currency_egp')}';
}
