import '../../../core/network/api_client.dart';
import 'accounting_models.dart';

/// Talks to the backend's `/accounting` router — the farm's revenue/expense
/// tree, the shared category dictionary, and the AI financial advisor.
class AccountingRepository {
  AccountingRepository(this._api);

  final ApiClient _api;

  int get _uid => _api.userId ?? 0;

  // ── Tree ───────────────────────────────────────────────────────────────

  /// The flat node list for a fiscal year. The hierarchy is rebuilt client-side
  /// from `parent_id`.
  Future<List<AccountingNode>> tree(int year, {int? farmId}) async {
    final data = await _api.get(
      '/accounting/tree/$_uid',
      query: {'year': year, 'farm_id': ?farmId},
    );
    final nodes = (data is Map) ? data['nodes'] : null;
    if (nodes is! List) return const [];
    return nodes
        .whereType<Map>()
        .map((e) => AccountingNode.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<AccountingNode> createNode({
    required String nodeType,
    required int fiscalYear,
    int? parentId,
    int? farmId,
    int? categoryId,
    String? customName,
    double totalAmount = 0,
    double? unitPrice,
    double? quantity,
    String? frequency,
    int sortOrder = 0,
  }) async {
    final data = await _api.post(
      '/accounting/node',
      body: {
        'user_id': _uid,
        'farm_id': farmId,
        'parent_id': parentId,
        'category_id': categoryId,
        'custom_name': customName,
        'node_type': nodeType,
        'fiscal_year': fiscalYear,
        'total_amount': totalAmount,
        'unit_price': unitPrice,
        'quantity': quantity,
        'frequency': frequency,
        'sort_order': sortOrder,
        'is_expanded': true,
      },
    );
    return AccountingNode.fromJson((data as Map).cast<String, dynamic>());
  }

  /// Partial update. Only the fields passed are sent; the backend ignores any
  /// it receives as null.
  ///
  /// [clearCustomName] exists because of that rule: sending `custom_name: null`
  /// is indistinguishable from omitting it, so a node that had a typed name
  /// would keep it forever after the user picked a category. An empty string
  /// is a value, so it overwrites.
  Future<void> updateNode(
    int nodeId, {
    int? categoryId,
    String? customName,
    bool clearCustomName = false,
    double? totalAmount,
    double? unitPrice,
    double? quantity,
    String? frequency,
    int? sortOrder,
    bool? isExpanded,
  }) async {
    await _api.put(
      '/accounting/node/$nodeId',
      body: {
        'user_id': _uid,
        'category_id': ?categoryId,
        'custom_name': ?(clearCustomName ? '' : customName),
        'total_amount': ?totalAmount,
        'unit_price': ?unitPrice,
        'quantity': ?quantity,
        'frequency': ?frequency,
        'sort_order': ?sortOrder,
        'is_expanded': ?isExpanded,
      },
    );
  }

  /// Deletes a node; the database cascades to its descendants.
  Future<void> deleteNode(int nodeId) async {
    await _api.delete('/accounting/node/$nodeId', query: {'user_id': _uid});
  }

  // ── Categories ─────────────────────────────────────────────────────────

  Future<List<AccountingCategory>> searchCategories({
    String query = '',
    String? nodeType,
    String lang = 'en',
  }) async {
    final data = await _api.get(
      '/accounting/categories',
      query: {'q': query, 'node_type': ?nodeType, 'lang': lang},
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => AccountingCategory.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// Adds a user-typed name to the shared dictionary so it can be picked next
  /// time. Returns the category id (existing or new).
  Future<int?> createCategory({
    required String nameEn,
    required String nameAr,
    required String nodeType,
    int? parentCategoryId,
  }) async {
    final data = await _api.post(
      '/accounting/categories',
      body: {
        'name_en': nameEn,
        'name_ar': nameAr,
        'node_type': nodeType,
        'parent_category_id': parentCategoryId,
      },
    );
    final id = (data is Map) ? data['id'] : null;
    return (id is num) ? id.toInt() : null;
  }

  // ── AI advisor ─────────────────────────────────────────────────────────

  /// Streams the financial analysis. [treeData] carries each node plus its
  /// rolled-up `computed_total`, which is what the prompt reports on.
  Stream<ChatToken> advise({
    required int fiscalYear,
    required List<Map<String, dynamic>> treeData,
    required double totalRevenue,
    required double totalExpenses,
    required double netProfit,
    required String lang,
    required String length,
  }) {
    return _api.streamChatTokens(
      '/accounting/ai-advisor',
      body: {
        'user_id': _uid,
        'fiscal_year': fiscalYear,
        'tree_data': treeData,
        'calculated_total_revenue': totalRevenue,
        'calculated_total_expenses': totalExpenses,
        'calculated_net_profit': netProfit,
        'lang': lang,
        'length': length,
      },
    );
  }

  // ── Saved reports ──────────────────────────────────────────────────────

  Future<void> saveReport({
    required int fiscalYear,
    required String content,
    required String lengthPreference,
    int? farmId,
  }) async {
    await _api.post(
      '/accounting/reports',
      body: {
        'user_id': _uid,
        'farm_id': farmId,
        'fiscal_year': fiscalYear,
        'report_content': content,
        'word_count_preference': lengthPreference,
      },
    );
  }

  Future<List<FinancialReport>> reports({int? farmId}) async {
    final data = await _api.get(
      '/accounting/reports/$_uid',
      query: {'farm_id': ?farmId},
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => FinancialReport.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
