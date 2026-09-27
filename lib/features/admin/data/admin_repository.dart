import '../../../core/network/api_client.dart';

class AdminAnalytics {
  const AdminAnalytics({
    this.totalUsers = 0,
    this.totalRevenue = 0,
    this.totalAiRuns = 0,
  });

  final int totalUsers;
  final double totalRevenue;
  final int totalAiRuns;

  factory AdminAnalytics.fromJson(Map<String, dynamic> j) => AdminAnalytics(
    totalUsers: (j['total_users'] as num?)?.toInt() ?? 0,
    totalRevenue: (j['revenue'] as num?)?.toDouble() ?? 0.0,
    totalAiRuns: (j['total_ai_runs'] as num?)?.toInt() ?? 0,
  );
}

class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.aiCredits = 0,
    this.subscriptionPlan,
    this.isVerified = false,
  });

  final int id;
  final String name;
  final String email;
  final String role;
  final int aiCredits;
  final String? subscriptionPlan;
  final bool isVerified;

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: (j['id'] as num).toInt(),
    name: (j['name'] ?? 'User ${j['id']}').toString(),
    email: (j['email'] ?? '').toString(),
    role: (j['role'] ?? 'User').toString(),
    aiCredits: (j['ai_credits'] as num?)?.toInt() ?? 0,
    subscriptionPlan: j['subscription_plan']?.toString(),
    isVerified: j['is_verified'] == 1 || j['is_verified'] == true,
  );
}

class PendingPayment {
  const PendingPayment({
    required this.id,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    this.screenshotPath,
    this.userName,
    this.userEmail,
    this.paymentDate,
  });

  final int id;
  final double amount;
  final String paymentMethod;
  final String status;
  final String? screenshotPath;
  final String? userName;
  final String? userEmail;
  final String? paymentDate;

  factory PendingPayment.fromJson(Map<String, dynamic> j) {
    final userMap = j['user'] is Map ? j['user'] as Map : null;
    return PendingPayment(
      id: (j['id'] as num).toInt(),
      amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: (j['payment_method'] ?? 'Transfer').toString(),
      status: (j['status'] ?? 'Pending').toString(),
      screenshotPath: j['transfer_screenshot_path']?.toString(),
      userName: userMap?['name']?.toString(),
      userEmail: userMap?['email']?.toString(),
      paymentDate: j['payment_date']?.toString(),
    );
  }
}

class AdminRepository {
  AdminRepository(this._api);

  final ApiClient _api;

  int get _uid => _api.userId ?? 0;

  Future<AdminAnalytics> fetchAnalytics() async {
    final data = await _api.get('/admin/analytics', query: {'user_id': _uid});
    if (data is Map) {
      return AdminAnalytics.fromJson(data.cast<String, dynamic>());
    }
    return const AdminAnalytics();
  }

  Future<List<AdminUser>> fetchUsers() async {
    final data = await _api.get('/admin/users', query: {'admin_id': _uid});
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => AdminUser.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Future<List<PendingPayment>> fetchPendingPayments() async {
    final data = await _api.get(
      '/admin/payments/pending',
      query: {'admin_id': _uid},
    );
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => PendingPayment.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Future<void> updatePaymentStatus(int billingId, String status) async {
    await _api.put(
      '/admin/payments/$billingId/status',
      body: {'admin_id': _uid, 'status': status},
    );
  }
}
