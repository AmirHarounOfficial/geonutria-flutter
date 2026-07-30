import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../devices/bloc/devices_cubit.dart';
import '../../../devices/data/automation_models.dart';
import '../../../devices/data/device_models.dart';
import '../sensor_meta.dart';
import 'automation_editor_sheet.dart';

/// Lists the user's automation rules under the quick-controls grid, with an
/// enable toggle per rule and a button to add one.
///
/// Hidden entirely when the user has no controls to act on — a rule needs a
/// target, so offering the builder first would be a dead end.
class AutomationsCard extends StatelessWidget {
  const AutomationsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DevicesCubit, DevicesState>(
      buildWhen: (a, b) =>
          a.automations != b.automations || a.devices != b.devices,
      builder: (context, state) {
        final targets = state.devices
            .where((d) => d.controls.isNotEmpty)
            .toList();
        if (targets.isEmpty) return const SizedBox.shrink();

        final rules = state.automations;

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
                      onPressed: () => _openEditor(context, targets, null),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(context.tr('add_rule')),
                    ),
                  ],
                ),
                if (rules.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
                    child: Text(
                      context.tr('automations_empty'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  )
                else
                  for (final rule in rules)
                    _RuleRow(
                      key: ValueKey(rule.id),
                      rule: rule,
                      devices: state.devices,
                      onEdit: () => _openEditor(context, targets, rule),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openEditor(
    BuildContext context,
    List<MyDevice> targets,
    AutomationRule? existing,
  ) {
    final cubit = context.read<DevicesCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: AutomationEditorSheet(
          targets: targets,
          sensorSources: cubit.state.devices,
          existing: existing,
        ),
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    super.key,
    required this.rule,
    required this.devices,
    required this.onEdit,
  });

  final AutomationRule rule;
  final List<MyDevice> devices;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              rule.isTimeTrigger ? Icons.access_time : Icons.sensors,
              size: 18,
              color: rule.enabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: rule.enabled ? null : theme.colorScheme.outline,
                    ),
                  ),
                  Text(
                    describeRule(rule, devices),
                    maxLines: 2,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  if (rule.lastError != null)
                    Text(
                      rule.lastError!,
                      maxLines: 2,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
            Switch(
              value: rule.enabled,
              onChanged: rule.id == null
                  ? null
                  : (v) => context.read<DevicesCubit>().setAutomationEnabled(
                      rule.id!,
                      v,
                    ),
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') {
                  onEdit();
                } else if (rule.id != null) {
                  context.read<DevicesCubit>().deleteAutomation(rule.id!);
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

/// Plain-language summary of a rule, e.g.
/// "Every day at 06:30 · Pump → On" or "Ambient Temp above 32°C · Fan → On".
String describeRule(AutomationRule rule, List<MyDevice> devices) {
  final action = rule.actionLabel ?? rule.actionTopic;
  final target = '$action → ${rule.actionPayload}';

  if (rule.isTimeTrigger) {
    final when = rule.runsDaily
        ? 'Every day'
        : rule.triggerDays.map((d) => kWeekdayLabels[d % 7]).join(', ');
    return '$when at ${rule.triggerTime ?? '--:--'} · $target';
  }

  final meta = SensorMeta.all.where((m) => m.key == rule.sensorKey);
  final label = meta.isEmpty ? (rule.sensorKey ?? 'Sensor') : meta.first.label;
  final unit = meta.isEmpty ? '' : meta.first.unit;
  final cmp = rule.comparator == Comparator.below ? 'below' : 'above';
  final threshold = rule.threshold?.toStringAsFixed(1) ?? '?';

  final device = devices.where((d) => d.id == rule.sourceDeviceId);
  final source = device.isEmpty ? '' : ' (${device.first.name})';

  return '$label$source $cmp $threshold$unit · $target';
}
