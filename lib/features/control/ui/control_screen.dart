import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/status_views.dart';
import '../../dashboard/bloc/history_cubit.dart' show LoadState;
import '../../farm_context/farm_hierarchy_cubit.dart';
import '../bloc/control_cubit.dart';
import '../data/control_models.dart';
import '../data/control_repository.dart';
import 'widgets/actuator_tile.dart';
import 'widgets/schedule_editor_sheet.dart';
import 'widgets/schedules_card.dart' show describeSchedule;

/// Dedicated Farm Control & Automation screen mirroring the web `ControlAutomationView.js`.
/// Provides:
/// 1. Manual Actuator Control grid (Pumps, LED, RGB, Valves, Fans) with animated toggles,
///    duration countdowns, and color pickers.
/// 2. Automation Schedules & Threshold Triggers management.
/// 3. AI Automation Advisor generating optimal schedules from farm sensors and weather.
class ControlScreen extends StatelessWidget {
  const ControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(48),
          child: Container(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: false,
              indicatorColor: Color(0xFFC47A2C),
              labelColor: Color(0xFFC47A2C),
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              tabs: [
                Tab(
                  icon: Icon(Icons.bolt, size: 18),
                  text: context.tr('nav_control'),
                ),
                Tab(
                  icon: Icon(Icons.schedule, size: 18),
                  text: context.tr('automations'),
                ),
                Tab(
                  icon: Icon(Icons.auto_awesome, size: 18),
                  text: context.tr('ai_advisor'),
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _ActuatorsTab(),
            _SchedulesTab(),
            _AiAdvisorTab(key: ValueKey(context.locale.languageCode)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// TAB 1: ACTUATORS GRID
// =============================================================================
class _ActuatorsTab extends StatelessWidget {
  const _ActuatorsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ControlCubit, ControlState>(
      builder: (context, state) {
        if (state.state == LoadState.loading && state.actuators.isEmpty) {
          return LoadingView();
        }

        if (state.actuators.isEmpty) {
          return EmptyView(
            message: state.error ?? context.tr('no_data'),
            icon: Icons.power_off,
          );
        }

        return RefreshIndicator(
          onRefresh: () => context.read<ControlCubit>().load(),
          child: ListView(
            padding: EdgeInsets.all(16),
            children: [
              Text(
                context.tr('quick_controls'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                context.ui(
                  'Live relay and device telemetry with real-time feedback.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: state.actuators.length,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 170,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (ctx, i) => ActuatorTile(
                  key: ValueKey(state.actuators[i].id),
                  actuator: state.actuators[i],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// TAB 2: SCHEDULES & THRESHOLD RULES
// =============================================================================
class _SchedulesTab extends StatelessWidget {
  const _SchedulesTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ControlCubit, ControlState>(
      builder: (context, state) {
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => openScheduleEditor(context, null),
            icon: Icon(Icons.add),
            label: Text(context.tr('add_rule')),
            backgroundColor: Color(0xFFC47A2C),
            foregroundColor: Colors.white,
          ),
          body: RefreshIndicator(
            onRefresh: () => context.read<ControlCubit>().load(),
            child: state.schedules.isEmpty
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule,
                            size: 64,
                            color: Colors.grey.withValues(alpha: 0.5),
                          ),
                          SizedBox(height: 16),
                          Text(
                            context.tr('automations_empty'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => openScheduleEditor(context, null),
                            icon: Icon(Icons.add),
                            label: Text(context.tr('add_rule')),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: state.schedules.length,
                    separatorBuilder: (_, _) => SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final schedule = state.schedules[i];
                      return _ScheduleCard(schedule: schedule);
                    },
                  ),
          ),
        );
      },
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.schedule});

  final Schedule schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = schedule.isActive;
    final isThreshold = schedule.triggerType == TriggerType.threshold;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: active
              ? Color(0xFFC47A2C).withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isThreshold
                      ? Colors.teal.withValues(alpha: 0.15)
                      : Colors.amber.withValues(alpha: 0.15),
                  child: Icon(
                    isThreshold ? Icons.sensors : Icons.access_time,
                    color: isThreshold ? Colors.teal : Colors.amber[800],
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule.name?.isNotEmpty == true
                            ? schedule.name!
                            : 'Rule ${schedule.id ?? ''}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        schedule.actuatorName ??
                            'Actuator #${schedule.actuatorId}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: active,
                  activeThumbColor: Color(0xFFC47A2C),
                  onChanged: schedule.id == null
                      ? null
                      : (_) => context.read<ControlCubit>().toggleSchedule(
                          schedule.id!,
                        ),
                ),
              ],
            ),
            Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    describeSchedule(schedule, context: context),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 20),
                  onPressed: () => openScheduleEditor(context, schedule),
                  tooltip: context.tr('edit'),
                ),
                if (schedule.id != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _confirmDelete(context),
                    tooltip: context.tr('delete'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('delete')),
        content: Text(
          context.ui(
            'Are you sure you want to remove this automation schedule?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ControlCubit>().deleteSchedule(schedule.id!);
            },
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TAB 3: AI AUTOMATION ADVISOR
// =============================================================================
class _AiAdvisorTab extends StatefulWidget {
  const _AiAdvisorTab({super.key});

  @override
  State<_AiAdvisorTab> createState() => _AiAdvisorTabState();
}

class _AiAdvisorTabState extends State<_AiAdvisorTab> {
  bool _streaming = false;
  final StringBuffer _advisorOutput = StringBuffer();
  String? _errorMessage;

  Future<void> _generateAdvice() async {
    setState(() {
      _streaming = true;
      _errorMessage = null;
      _advisorOutput.clear();
    });

    try {
      final repo = ControlRepository(context.read<ApiClient>());
      final farmState = context.read<FarmHierarchyCubit>().state;
      final lang = context.locale.languageCode == 'ar' ? 'ar' : 'en';

      final stream = repo.suggestAutomationStream(
        farmId: farmState.selectedFarmId,
        lang: lang,
      );

      await for (final token in stream) {
        if (!mounted) return;
        setState(() {
          if (!token.isReasoning) _advisorOutput.write(token.text);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to generate automation advice: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _streaming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = _advisorOutput.isNotEmpty;

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Card(
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
                      backgroundColor: Color(0xFFC47A2C),
                      child: Icon(Icons.psychology, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.ui('Autonomous Agronomy Engine'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            context.ui(
                              'Generates science-backed pump & lighting schedules using live IoT telemetry.',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _streaming ? null : _generateAdvice,
                  style: FilledButton.styleFrom(
                    backgroundColor: Color(0xFFC47A2C),
                    minimumSize: Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _streaming
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Icon(Icons.auto_awesome),
                  label: Text(
                    context.ui(
                      _streaming
                          ? 'Analyzing Farm Conditions…'
                          : 'Generate AI Automation Plan',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_errorMessage != null) ...[
          SizedBox(height: 12),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.redAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (hasContent) ...[
          SizedBox(height: 16),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: MarkdownBody(
                data: _advisorOutput.toString(),
                styleSheet: MarkdownStyleSheet.fromTheme(theme),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
