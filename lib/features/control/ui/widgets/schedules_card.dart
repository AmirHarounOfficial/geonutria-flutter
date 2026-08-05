import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../bloc/control_cubit.dart';
import '../../data/control_models.dart';
import 'schedule_editor_sheet.dart';

/// Lists the user's automation schedules under the actuator grid.
///
/// Hidden when there are no actuators — a schedule needs something to act on,
/// so offering the builder first would be a dead end.
class SchedulesCard extends StatelessWidget {
  const SchedulesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ControlCubit, ControlState>(
      buildWhen: (a, b) =>
          a.schedules != b.schedules || a.actuators != b.actuators,
      builder: (context, state) {
        if (state.actuators.isEmpty) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.tr('automations'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => openScheduleEditor(context, null),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(context.tr('add_rule')),
                    ),
                  ],
                ),
                if (state.schedules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                    child: Text(
                      context.tr('automations_empty'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  for (final s in state.schedules)
                    _ScheduleRow(key: ValueKey(s.id), schedule: s),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({super.key, required this.schedule});
  final Schedule schedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = schedule.isActive;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              schedule.triggerType == TriggerType.threshold
                  ? Icons.sensors
                  : Icons.access_time,
              size: 18,
              color: active
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule.name?.isNotEmpty == true
                        ? schedule.name!
                        : 'Rule ${schedule.id ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: active ? null : theme.colorScheme.outline,
                    ),
                  ),
                  Text(
                    describeSchedule(schedule),
                    maxLines: 2,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: active,
              onChanged: schedule.id == null
                  ? null
                  : (_) => context.read<ControlCubit>().toggleSchedule(
                      schedule.id!,
                    ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  openScheduleEditor(context, schedule);
                } else if (schedule.id != null) {
                  context.read<ControlCubit>().deleteSchedule(schedule.id!);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ],
        ),
        const Divider(height: 4),
      ],
    );
  }
}

/// Plain-language summary of a schedule, e.g.
/// "Every day at 06:30 · Pump → on for 15 min" or
/// "Soil Moisture below 30 · Pump → on".
String describeSchedule(Schedule s) {
  final target = s.actuatorName ?? 'Actuator ${s.actuatorId}';
  final duration = s.durationMinutes != null
      ? ' for ${s.durationMinutes} min'
      : '';
  final action = '$target → ${s.action}$duration';

  if (s.triggerType == TriggerType.threshold) {
    final metric = kStandardMetrics[s.sensor] ?? s.sensor ?? 'Sensor';
    final op = switch (s.operator) {
      '<' => 'below',
      '<=' => 'at or below',
      '>=' => 'at or above',
      '==' => 'exactly',
      _ => 'above',
    };
    final value = s.threshold?.toStringAsFixed(1) ?? '?';
    return '$metric $op $value · $action';
  }

  final when = describeCron(s.cronExpression);
  return '$when · $action';
}

/// Turns a cron expression back into something a farmer can read.
/// Falls back to showing the raw expression rather than guessing wrongly.
String describeCron(String? cron) {
  if (cron == null || cron.trim().isEmpty) return 'No schedule';
  final parsed = parseCron(cron);
  final hh = parsed.hour.toString().padLeft(2, '0');
  final mm = parsed.minute.toString().padLeft(2, '0');
  if (parsed.days.isEmpty) return 'Every day at $hh:$mm';
  // Keep chip order stable rather than set order.
  final ordered = kScheduleDays.where(parsed.days.contains).join(', ');
  return '$ordered at $hh:$mm';
}
