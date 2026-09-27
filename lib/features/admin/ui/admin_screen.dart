import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/status_views.dart';
import '../../dashboard/bloc/history_cubit.dart' show LoadState;
import '../bloc/admin_cubit.dart';
import '../data/admin_repository.dart';
import 'admin_management.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          AdminCubit(AdminRepository(ctx.read<ApiClient>()))..loadAll(),
      child: const _AdminView(),
    );
  }
}

class _AdminView extends StatelessWidget {
  const _AdminView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminCubit, AdminState>(
      listenWhen: (a, b) =>
          a.actionMessage != b.actionMessage && b.actionMessage != null,
      listener: (ctx, state) {
        ScaffoldMessenger.of(ctx)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(state.actionMessage!),
              backgroundColor: Colors.green,
            ),
          );
      },
      child: DefaultTabController(
        length: 5,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              child: TabBar(
                isScrollable: true,
                indicatorColor: Color(0xFFC47A2C),
                labelColor: Color(0xFFC47A2C),
                unselectedLabelColor: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant,
                tabs: [
                  Tab(
                    icon: Icon(Icons.sensors),
                    text: context.ui('Sensor devices'),
                  ),
                  Tab(icon: Icon(Icons.bolt), text: context.ui('Actuators')),
                  Tab(
                    icon: Icon(Icons.analytics_outlined, size: 18),
                    text: context.ui('Overview'),
                  ),
                  Tab(
                    icon: Icon(Icons.people_outline, size: 18),
                    text: context.ui('Users'),
                  ),
                  Tab(
                    icon: Icon(Icons.payments_outlined, size: 18),
                    text: context.ui('Payments'),
                  ),
                ],
              ),
            ),
          ),
          body: TabBarView(
            children: [
              AdminInventory(actuators: false),
              AdminInventory(actuators: true),
              _OverviewTab(),
              _UsersTab(),
              _PendingPaymentsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// TAB 1: OVERVIEW ANALYTICS
// =============================================================================
class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminCubit, AdminState>(
      builder: (context, state) {
        if (state.state == LoadState.loading) return LoadingView();
        if (state.state == LoadState.error) {
          return ErrorView(
            message: state.error ?? context.tr('error_generic'),
            onRetry: () => context.read<AdminCubit>().loadAll(),
          );
        }

        final a = state.analytics;
        return RefreshIndicator(
          onRefresh: () => context.read<AdminCubit>().loadAll(),
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              Text(
                context.ui('Platform Telemetry & Analytics'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                context.ui(
                  'High-level metrics across all GeoNutria user activity.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              SizedBox(height: 16),
              _MetricCard(
                title: context.ui('Total Users'),
                value: '${a.totalUsers}',
                icon: Icons.people,
                color: Colors.blue,
              ),
              SizedBox(height: 12),
              _MetricCard(
                title: context.ui('Total Revenue'),
                value: '\$${a.totalRevenue.toStringAsFixed(2)}',
                icon: Icons.attach_money,
                color: Colors.green,
              ),
              SizedBox(height: 12),
              _MetricCard(
                title: context.ui('Total AI Runs'),
                value: '${a.totalAiRuns}',
                icon: Icons.auto_awesome,
                color: Colors.purple,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: 0.15),
              child: Icon(icon, color: color, size: 30),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                  ),
                  SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TAB 2: USERS LIST
// =============================================================================
class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _searchCtl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminCubit, AdminState>(
      builder: (context, state) {
        if (state.state == LoadState.loading) return LoadingView();

        final filtered = state.users.where((u) {
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: TextField(
                controller: _searchCtl,
                decoration: InputDecoration(
                  hintText: context.ui('Search users by name or email…'),
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
                onChanged: (val) => setState(() => _query = val.trim()),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => context.read<AdminCubit>().loadAll(),
                child: filtered.isEmpty
                    ? EmptyView(
                        message: 'No users found',
                        icon: Icons.person_off,
                      )
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final u = filtered[i];
                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Color(
                                  0xFFC47A2C,
                                ).withValues(alpha: 0.15),
                                child: Text(
                                  u.name.isNotEmpty
                                      ? u.name[0].toUpperCase()
                                      : 'U',
                                  style: TextStyle(
                                    color: Color(0xFFC47A2C),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AdminUserDetails(userId: u.id),
                                ),
                              ),
                              title: Text(
                                u.name,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                '${u.email}\n${context.ui('Role')}: ${context.ui(u.role)} · ${context.ui('Plan')}: ${context.ui(u.subscriptionPlan ?? 'Free')}',
                              ),
                              isThreeLine: true,
                              trailing: Chip(
                                avatar: Icon(
                                  Icons.bolt,
                                  size: 16,
                                  color: Color(0xFFC47A2C),
                                ),
                                label: Text('${u.aiCredits}⚡'),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// =============================================================================
// TAB 3: PENDING PAYMENT APPROVALS
// =============================================================================
class _PendingPaymentsTab extends StatelessWidget {
  const _PendingPaymentsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminCubit, AdminState>(
      builder: (context, state) {
        if (state.state == LoadState.loading) return LoadingView();

        final payments = state.pendingPayments;
        return RefreshIndicator(
          onRefresh: () => context.read<AdminCubit>().loadAll(),
          child: payments.isEmpty
              ? EmptyView(
                  message: 'No pending payments for review.',
                  icon: Icons.check_circle_outline,
                )
              : ListView.separated(
                  padding: EdgeInsets.all(16),
                  itemCount: payments.length,
                  separatorBuilder: (_, _) => SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final p = payments[i];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: Colors.teal.withValues(
                                    alpha: 0.15,
                                  ),
                                  child: Icon(
                                    Icons.receipt_long,
                                    color: Colors.teal,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.userName ?? 'User #${p.id}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (p.userEmail != null)
                                        Text(
                                          p.userEmail!,
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '\$${p.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFC47A2C),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            Text('${context.ui('Method')} ${p.paymentMethod}'),
                            if (p.paymentDate != null)
                              Text('${context.ui('Date')} ${p.paymentDate}'),
                            if (p.screenshotPath != null &&
                                p.screenshotPath!.isNotEmpty) ...[
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.image,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        p.screenshotPath!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton(
                                  onPressed: () => context
                                      .read<AdminCubit>()
                                      .processPayment(p.id, false),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.redAccent,
                                  ),
                                  child: Text(context.ui('Reject')),
                                ),
                                SizedBox(width: 12),
                                FilledButton(
                                  onPressed: () => context
                                      .read<AdminCubit>()
                                      .processPayment(p.id, true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Color(0xFF6B8F71),
                                  ),
                                  child: Text(context.ui('Approve & Credit')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
