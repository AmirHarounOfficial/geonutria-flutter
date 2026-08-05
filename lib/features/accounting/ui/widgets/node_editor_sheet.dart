import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../bloc/accounting_cubit.dart';
import '../../data/accounting_models.dart';
import '../../data/accounting_repository.dart';

/// Editor for a single line in the accounting tree.
///
/// Kept as a sheet rather than inline fields: a phone row has space for a name
/// and an amount, not for the five fields a line can carry.
class NodeEditorSheet extends StatefulWidget {
  const NodeEditorSheet({
    super.key,
    required this.node,
    required this.cubit,
    required this.repo,
    required this.hasChildren,
    required this.computedTotal,
  });

  final AccountingNode node;
  final AccountingCubit cubit;
  final AccountingRepository repo;

  /// A parent's amount is the sum of its children, so its own amount field is
  /// meaningless and is shown read-only.
  final bool hasChildren;

  final double computedTotal;

  static Future<void> show(
    BuildContext context, {
    required AccountingNode node,
    required AccountingCubit cubit,
    required AccountingRepository repo,
    required bool hasChildren,
    required double computedTotal,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => NodeEditorSheet(
        node: node,
        cubit: cubit,
        repo: repo,
        hasChildren: hasChildren,
        computedTotal: computedTotal,
      ),
    );
  }

  @override
  State<NodeEditorSheet> createState() => _NodeEditorSheetState();
}

class _NodeEditorSheetState extends State<NodeEditorSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: _trim(widget.node.totalAmount),
  );
  late final TextEditingController _unitPrice = TextEditingController(
    text: widget.node.unitPrice == null ? '' : _trim(widget.node.unitPrice!),
  );
  late final TextEditingController _quantity = TextEditingController(
    text: widget.node.quantity == null ? '' : _trim(widget.node.quantity!),
  );

  String? _frequency;
  AccountingCategory? _pickedCategory;
  String? _pickedCustomName;

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void initState() {
    super.initState();
    _frequency = widget.node.frequency;
  }

  @override
  void dispose() {
    _amount.dispose();
    _unitPrice.dispose();
    _quantity.dispose();
    super.dispose();
  }

  /// Keeps the amount in step when a unit price and quantity are given, so the
  /// two can't disagree with the total the tree sums.
  void _recalc() {
    final price = double.tryParse(_unitPrice.text.trim());
    final qty = double.tryParse(_quantity.text.trim());
    if (price == null || qty == null) return;
    _amount.text = _trim(price * qty);
    setState(() {});
  }

  void _save() {
    widget.cubit.editNode(
      widget.node.id,
      categoryId: _pickedCategory?.id,
      // Picking a category has to clear any name typed earlier, or the old
      // text would keep winning when the row is rendered.
      clearCustomName: _pickedCategory != null,
      customName: _pickedCustomName,
      categoryNameEn: _pickedCategory?.nameEn,
      categoryNameAr: _pickedCategory?.nameAr,
      totalAmount: widget.hasChildren
          ? null
          : double.tryParse(_amount.text.trim()) ?? 0,
      unitPrice: double.tryParse(_unitPrice.text.trim()),
      quantity: double.tryParse(_quantity.text.trim()),
      frequency: _frequency,
    );
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('delete_line')),
        content: Text(
          widget.hasChildren
              ? context.tr('delete_line_children_warning')
              : context.tr('delete_line_confirm'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    widget.cubit.deleteNode(widget.node.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = context.locale.languageCode;
    final currentName =
        _pickedCategory?.name(lang) ??
        _pickedCustomName ??
        widget.node.displayName(lang);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.node.isRevenue
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: widget.node.isRevenue
                      ? Colors.green
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    currentName.isEmpty ? context.tr('unnamed') : currentName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: context.tr('delete'),
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: _confirmDelete,
                ),
              ],
            ),
            const SizedBox(height: 12),
            CategoryField(
              repo: widget.repo,
              nodeType: widget.node.nodeType,
              initialText: widget.node.displayName(lang),
              onCategoryPicked: (cat) => setState(() {
                _pickedCategory = cat;
                _pickedCustomName = null;
              }),
              onCustomName: (name) => setState(() {
                _pickedCustomName = name;
                _pickedCategory = null;
              }),
            ),
            const SizedBox(height: 16),
            if (widget.hasChildren)
              // Read-only on purpose: this line's figure comes from the lines
              // beneath it, and letting both be edited invites a total that
              // doesn't match its parts.
              InputDecorator(
                decoration: InputDecoration(
                  labelText: context.tr('amount'),
                  helperText: context.tr('amount_from_children'),
                  prefixIcon: const Icon(Icons.functions),
                  isDense: true,
                ),
                child: Text(
                  widget.computedTotal.toStringAsFixed(2),
                  style: theme.textTheme.titleMedium,
                ),
              )
            else
              TextField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: context.tr('amount'),
                  suffixText: context.tr('currency_egp'),
                  prefixIcon: const Icon(Icons.payments_outlined),
                  isDense: true,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              context.tr('optional_breakdown'),
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _unitPrice,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (_) => _recalc(),
                    decoration: InputDecoration(
                      labelText: context.tr('unit_price'),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    onChanged: (_) => _recalc(),
                    decoration: InputDecoration(
                      labelText: context.tr('quantity'),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.tr('frequency'),
                prefixIcon: const Icon(Icons.repeat),
                isDense: true,
                helperText: context.tr('frequency_hint'),
              ),
              items: [
                for (final f in Frequency.all)
                  DropdownMenuItem(value: f, child: Text(context.tr('freq_$f'))),
              ],
              onChanged: (v) => setState(() => _frequency = v),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(context.tr('save')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// Searches the shared category dictionary, and offers to add whatever the
/// user typed if nothing matches.
class CategoryField extends StatefulWidget {
  const CategoryField({
    super.key,
    required this.repo,
    required this.nodeType,
    required this.onCategoryPicked,
    required this.onCustomName,
    this.initialText = '',
  });

  final AccountingRepository repo;
  final String nodeType;
  final ValueChanged<AccountingCategory> onCategoryPicked;
  final ValueChanged<String> onCustomName;
  final String initialText;

  @override
  State<CategoryField> createState() => _CategoryFieldState();
}

class _CategoryFieldState extends State<CategoryField> {
  late final TextEditingController _search = TextEditingController(
    text: widget.initialText,
  );
  Timer? _debounce;
  List<AccountingCategory> _results = const [];
  bool _loading = false;
  bool _open = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onCustomName(value.trim());
    _debounce?.cancel();
    // One request per pause rather than per keystroke — the dictionary is
    // shared and the search is a LIKE scan.
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => _runSearch(value),
    );
  }

  Future<void> _runSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _results = const []);
      return;
    }
    setState(() {
      _loading = true;
      _open = true;
    });
    try {
      final results = await widget.repo.searchCategories(
        query: query.trim(),
        nodeType: widget.nodeType,
        lang: context.locale.languageCode,
      );
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // The typed text still works as a custom name, so a failed lookup only
      // costs the suggestions.
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  Future<void> _createCategory() async {
    final name = _search.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    try {
      final id = await widget.repo.createCategory(
        // The user has one language open; the dictionary needs both columns,
        // so the same text is stored on each side until someone translates it.
        nameEn: name,
        nameAr: name,
        nodeType: widget.nodeType,
      );
      if (!mounted) return;
      if (id != null) {
        widget.onCategoryPicked(
          AccountingCategory(
            id: id,
            nameEn: name,
            nameAr: name,
            nodeType: widget.nodeType,
          ),
        );
      }
      setState(() {
        _loading = false;
        _open = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lang = context.locale.languageCode;
    final typed = _search.text.trim();
    final exactMatch = _results.any(
      (c) => c.name(lang).toLowerCase() == typed.toLowerCase(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _search,
          onChanged: _onChanged,
          decoration: InputDecoration(
            labelText: context.tr('line_name'),
            hintText: context.tr('category_placeholder'),
            prefixIcon: const Icon(Icons.label_outline),
            isDense: true,
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (_open && (_results.isNotEmpty || (typed.isNotEmpty && !_loading)))
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final c in _results)
                  ListTile(
                    dense: true,
                    title: Text(c.name(lang)),
                    onTap: () {
                      _search.text = c.name(lang);
                      widget.onCategoryPicked(c);
                      setState(() => _open = false);
                    },
                  ),
                if (typed.isNotEmpty && !exactMatch)
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.add, color: theme.colorScheme.primary),
                    title: Text(
                      context.tr('add_new_category').replaceAll('{name}', typed),
                      style: TextStyle(color: theme.colorScheme.primary),
                    ),
                    onTap: _createCategory,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
