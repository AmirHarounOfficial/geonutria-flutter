import 'package:equatable/equatable.dart';

/// Which side of the ledger a node sits on.
class NodeType {
  const NodeType._();
  static const revenue = 'revenue';
  static const expense = 'expense';
}

/// How often a cost or income recurs. Descriptive only — the backend prints it
/// alongside the amount for the advisor and does not multiply by it, so the
/// amount a user enters is the amount for the year.
class Frequency {
  const Frequency._();
  static const all = ['daily', 'weekly', 'monthly', 'seasonally', 'yearly'];
}

/// A row in the farm's accounting tree.
///
/// The API returns a flat list; [parentId] is what makes it a tree, and the
/// client rebuilds the hierarchy (mirroring the web).
class AccountingNode extends Equatable {
  const AccountingNode({
    required this.id,
    required this.nodeType,
    required this.fiscalYear,
    this.userId,
    this.farmId,
    this.parentId,
    this.categoryId,
    this.customName,
    this.totalAmount = 0,
    this.unitPrice,
    this.quantity,
    this.frequency,
    this.sortOrder = 0,
    this.isExpanded = true,
    this.categoryNameEn,
    this.categoryNameAr,
  });

  final int id;
  final int? userId;
  final int? farmId;
  final int? parentId;
  final int? categoryId;

  /// Set when the user typed a name instead of picking a category.
  final String? customName;

  final String nodeType;
  final int fiscalYear;
  final double totalAmount;
  final double? unitPrice;
  final double? quantity;
  final String? frequency;
  final int sortOrder;
  final bool isExpanded;
  final String? categoryNameEn;
  final String? categoryNameAr;

  bool get isRevenue => nodeType == NodeType.revenue;

  /// Falls back across languages before giving up: a node the user named in
  /// one language should still be identifiable in the other.
  String displayName(String lang) {
    final localized = lang == 'ar' ? categoryNameAr : categoryNameEn;
    final other = lang == 'ar' ? categoryNameEn : categoryNameAr;
    final name = customName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (localized != null && localized.isNotEmpty) return localized;
    if (other != null && other.isNotEmpty) return other;
    return '';
  }

  AccountingNode copyWith({
    int? parentId,
    int? categoryId,
    String? customName,
    double? totalAmount,
    double? unitPrice,
    double? quantity,
    String? frequency,
    int? sortOrder,
    bool? isExpanded,
    String? categoryNameEn,
    String? categoryNameAr,
  }) => AccountingNode(
    id: id,
    userId: userId,
    farmId: farmId,
    parentId: parentId ?? this.parentId,
    categoryId: categoryId ?? this.categoryId,
    customName: customName ?? this.customName,
    nodeType: nodeType,
    fiscalYear: fiscalYear,
    totalAmount: totalAmount ?? this.totalAmount,
    unitPrice: unitPrice ?? this.unitPrice,
    quantity: quantity ?? this.quantity,
    frequency: frequency ?? this.frequency,
    sortOrder: sortOrder ?? this.sortOrder,
    isExpanded: isExpanded ?? this.isExpanded,
    categoryNameEn: categoryNameEn ?? this.categoryNameEn,
    categoryNameAr: categoryNameAr ?? this.categoryNameAr,
  );

  factory AccountingNode.fromJson(Map<String, dynamic> j) => AccountingNode(
    id: (j['id'] as num).toInt(),
    userId: (j['user_id'] as num?)?.toInt(),
    farmId: (j['farm_id'] as num?)?.toInt(),
    parentId: (j['parent_id'] as num?)?.toInt(),
    categoryId: (j['category_id'] as num?)?.toInt(),
    customName: j['custom_name']?.toString(),
    nodeType: (j['node_type'] ?? NodeType.expense).toString(),
    fiscalYear: (j['fiscal_year'] as num?)?.toInt() ?? 0,
    totalAmount: _toD(j['total_amount']) ?? 0,
    unitPrice: _toD(j['unit_price']),
    quantity: _toD(j['quantity']),
    frequency: j['frequency']?.toString(),
    sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
    isExpanded: j['is_expanded'] != false,
    categoryNameEn: j['category_name_en']?.toString(),
    categoryNameAr: j['category_name_ar']?.toString(),
  );

  @override
  List<Object?> get props => [
    id,
    parentId,
    categoryId,
    customName,
    nodeType,
    totalAmount,
    unitPrice,
    quantity,
    frequency,
    sortOrder,
    isExpanded,
    categoryNameEn,
    categoryNameAr,
  ];
}

/// An entry in the shared bilingual category dictionary.
class AccountingCategory extends Equatable {
  const AccountingCategory({
    required this.id,
    required this.nameEn,
    required this.nameAr,
    required this.nodeType,
    this.parentCategoryId,
    this.isSystem = false,
  });

  final int id;
  final String nameEn;
  final String nameAr;
  final String nodeType;
  final int? parentCategoryId;
  final bool isSystem;

  String name(String lang) {
    final localized = lang == 'ar' ? nameAr : nameEn;
    return localized.isNotEmpty ? localized : (lang == 'ar' ? nameEn : nameAr);
  }

  factory AccountingCategory.fromJson(Map<String, dynamic> j) =>
      AccountingCategory(
        id: (j['id'] as num).toInt(),
        nameEn: (j['name_en'] ?? '').toString(),
        nameAr: (j['name_ar'] ?? '').toString(),
        nodeType: (j['node_type'] ?? '').toString(),
        parentCategoryId: (j['parent_category_id'] as num?)?.toInt(),
        isSystem: j['is_system'] == true,
      );

  @override
  List<Object?> get props => [id, nameEn, nameAr, nodeType];
}

/// A saved AI financial report.
class FinancialReport extends Equatable {
  const FinancialReport({
    required this.id,
    required this.fiscalYear,
    required this.content,
    this.lengthPreference,
    this.createdAt,
  });

  final int id;
  final int fiscalYear;
  final String content;
  final String? lengthPreference;
  final String? createdAt;

  factory FinancialReport.fromJson(Map<String, dynamic> j) => FinancialReport(
    id: (j['id'] as num).toInt(),
    fiscalYear: (j['fiscal_year'] as num?)?.toInt() ?? 0,
    content: (j['report_content'] ?? '').toString(),
    lengthPreference: j['word_count_preference']?.toString(),
    createdAt: j['created_at']?.toString(),
  );

  @override
  List<Object?> get props => [id, fiscalYear, content, createdAt];
}

double? _toD(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}
