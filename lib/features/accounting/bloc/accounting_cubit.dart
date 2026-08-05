import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_exception.dart';
import '../data/accounting_models.dart';
import '../data/accounting_repository.dart';

enum AccountingStatus { initial, loading, loaded, error }

class AccountingState extends Equatable {
  const AccountingState({
    required this.year,
    this.status = AccountingStatus.initial,
    this.nodes = const [],
    this.childrenOf = const {},
    this.totals = const {},
    this.error,
    this.busy = false,
  });

  final int year;
  final AccountingStatus status;
  final List<AccountingNode> nodes;

  /// Children indexed by parent id; the root buckets live under key `null`,
  /// which a `Map<int?, …>` handles directly.
  final Map<int?, List<AccountingNode>> childrenOf;

  /// Rolled-up total per node id, precomputed so the tree can be rendered
  /// without re-walking the list for every row.
  final Map<int, double> totals;

  final String? error;

  /// True while a write is in flight, to keep the UI from firing a second one.
  final bool busy;

  List<AccountingNode> get revenueRoots => [
    for (final n in childrenOf[null] ?? const <AccountingNode>[])
      if (n.isRevenue) n,
  ];

  List<AccountingNode> get expenseRoots => [
    for (final n in childrenOf[null] ?? const <AccountingNode>[])
      if (!n.isRevenue) n,
  ];

  /// Only roots are summed — a parent already includes its children, so adding
  /// every node would count the same money at each level of the tree.
  double get totalRevenue =>
      revenueRoots.fold(0.0, (s, n) => s + (totals[n.id] ?? 0));

  double get totalExpenses =>
      expenseRoots.fold(0.0, (s, n) => s + (totals[n.id] ?? 0));

  double get netProfit => totalRevenue - totalExpenses;

  bool get isEmpty => nodes.isEmpty;

  /// Nodes with their rolled-up totals attached, as the advisor endpoint
  /// expects them.
  List<Map<String, dynamic>> get treeData => [
    for (final n in nodes)
      {
        'id': n.id,
        'parent_id': n.parentId,
        'node_type': n.nodeType,
        'custom_name': n.customName,
        'category_name_en': n.categoryNameEn,
        'category_name_ar': n.categoryNameAr,
        'total_amount': n.totalAmount,
        'unit_price': n.unitPrice,
        'quantity': n.quantity,
        'frequency': n.frequency,
        'computed_total': totals[n.id] ?? 0,
      },
  ];

  AccountingState copyWith({
    int? year,
    AccountingStatus? status,
    List<AccountingNode>? nodes,
    String? error,
    bool? busy,
  }) {
    final list = nodes ?? this.nodes;
    final rebuild = nodes != null;
    return AccountingState(
      year: year ?? this.year,
      status: status ?? this.status,
      nodes: list,
      childrenOf: rebuild ? _index(list) : childrenOf,
      totals: rebuild ? _rollUp(list) : totals,
      error: error,
      busy: busy ?? this.busy,
    );
  }

  /// Groups nodes by parent, preserving the server's ordering.
  static Map<int?, List<AccountingNode>> _index(List<AccountingNode> nodes) {
    final out = <int?, List<AccountingNode>>{};
    for (final n in nodes) {
      out.putIfAbsent(n.parentId, () => []).add(n);
    }
    return out;
  }

  /// A parent's total is the sum of its children; only leaves contribute their
  /// own amount. Entering a figure on a parent that has children is therefore
  /// ignored, which is what keeps the two levels from being added together.
  static Map<int, double> _rollUp(List<AccountingNode> nodes) {
    final children = _index(nodes);
    final totals = <int, double>{};
    final visiting = <int>{};

    double total(AccountingNode node) {
      final cached = totals[node.id];
      if (cached != null) return cached;
      // A parent cycle would otherwise recurse forever. The API shouldn't
      // produce one, but a bad row must not hang the screen.
      if (!visiting.add(node.id)) return 0;

      final kids = children[node.id] ?? const <AccountingNode>[];
      final sum = kids.isEmpty
          ? node.totalAmount
          : kids.fold(0.0, (s, c) => s + total(c));

      visiting.remove(node.id);
      totals[node.id] = sum;
      return sum;
    }

    for (final n in nodes) {
      total(n);
    }
    return totals;
  }

  @override
  List<Object?> get props => [year, status, nodes, error, busy];
}

/// Owns the farm's accounting tree for one fiscal year.
///
/// Writes are applied locally first and reverted if the request fails — the
/// tree is edited field by field, and waiting for a round trip on each one
/// makes it feel broken.
class AccountingCubit extends Cubit<AccountingState> {
  AccountingCubit(this._repo, {required int year})
    : super(AccountingState(year: year));

  final AccountingRepository _repo;

  Future<void> load({int? year}) async {
    final y = year ?? state.year;
    emit(
      state.copyWith(
        year: y,
        status: AccountingStatus.loading,
        error: null,
        nodes: const [],
      ),
    );
    try {
      final nodes = await _repo.tree(y);
      if (isClosed) return;
      emit(state.copyWith(status: AccountingStatus.loaded, nodes: nodes));
    } on AppException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(status: AccountingStatus.error, error: e.message));
    }
  }

  Future<void> addNode({
    required String nodeType,
    int? parentId,
    String? customName,
    int? categoryId,
    double amount = 0,
  }) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, error: null));
    try {
      final created = await _repo.createNode(
        nodeType: nodeType,
        fiscalYear: state.year,
        parentId: parentId,
        customName: customName,
        categoryId: categoryId,
        totalAmount: amount,
        sortOrder: (state.childrenOf[parentId]?.length ?? 0),
      );
      if (isClosed) return;
      emit(state.copyWith(nodes: [...state.nodes, created], busy: false));
    } on AppException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(busy: false, error: e.message));
    }
  }

  /// Applies an edit locally, then persists it. On failure the previous node is
  /// put back so the screen never shows a value the server rejected.
  Future<void> editNode(
    int nodeId, {
    int? categoryId,
    String? customName,
    bool clearCustomName = false,
    double? totalAmount,
    double? unitPrice,
    double? quantity,
    String? frequency,
    String? categoryNameEn,
    String? categoryNameAr,
  }) async {
    final index = state.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return;
    final previous = state.nodes[index];

    // Unit price and quantity drive the total, matching the web: whichever of
    // the two the user just changed, the product becomes the amount.
    var amount = totalAmount;
    if (unitPrice != null) {
      amount = unitPrice * (quantity ?? previous.quantity ?? 0);
    } else if (quantity != null) {
      amount = (unitPrice ?? previous.unitPrice ?? 0) * quantity;
    }

    final updated = previous.copyWith(
      categoryId: categoryId,
      customName: clearCustomName ? '' : customName,
      totalAmount: amount,
      unitPrice: unitPrice,
      quantity: quantity,
      frequency: frequency,
      categoryNameEn: categoryNameEn,
      categoryNameAr: categoryNameAr,
    );

    final optimistic = [...state.nodes]..[index] = updated;
    emit(state.copyWith(nodes: optimistic, error: null));

    try {
      await _repo.updateNode(
        nodeId,
        categoryId: categoryId,
        customName: customName,
        clearCustomName: clearCustomName,
        totalAmount: amount,
        unitPrice: unitPrice,
        quantity: quantity,
        frequency: frequency,
      );
    } on AppException catch (e) {
      if (isClosed) return;
      final current = [...state.nodes];
      final at = current.indexWhere((n) => n.id == nodeId);
      if (at >= 0) current[at] = previous;
      emit(state.copyWith(nodes: current, error: e.message));
    }
  }

  /// Removes a node and everything under it — the database cascades, so the
  /// local tree has to drop the whole subtree to stay in step.
  Future<void> deleteNode(int nodeId) async {
    final doomed = _subtreeIds(nodeId);
    final previous = state.nodes;
    emit(
      state.copyWith(
        nodes: [
          for (final n in state.nodes)
            if (!doomed.contains(n.id)) n,
        ],
        error: null,
      ),
    );
    try {
      await _repo.deleteNode(nodeId);
    } on AppException catch (e) {
      if (isClosed) return;
      emit(state.copyWith(nodes: previous, error: e.message));
    }
  }

  Set<int> _subtreeIds(int rootId) {
    final ids = <int>{rootId};
    final queue = <int>[rootId];
    while (queue.isNotEmpty) {
      final id = queue.removeLast();
      for (final child in state.childrenOf[id] ?? const <AccountingNode>[]) {
        if (ids.add(child.id)) queue.add(child.id);
      }
    }
    return ids;
  }

  /// Expansion is persisted so a tree opens the way the user left it.
  Future<void> toggleExpanded(int nodeId) async {
    final index = state.nodes.indexWhere((n) => n.id == nodeId);
    if (index < 0) return;
    final node = state.nodes[index];
    final value = !node.isExpanded;
    final nodes = [...state.nodes]..[index] = node.copyWith(isExpanded: value);
    emit(state.copyWith(nodes: nodes));
    try {
      await _repo.updateNode(nodeId, isExpanded: value);
    } on AppException {
      // A failed toggle is not worth interrupting the user for; the local
      // state stays as they left it and the next load resyncs.
    }
  }

  void clearError() => emit(state.copyWith(error: null));
}
