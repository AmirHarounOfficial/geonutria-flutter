import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../devices/bloc/devices_cubit.dart';
import '../../../devices/data/automation_models.dart';
import '../../../devices/data/device_models.dart';
import '../sensor_meta.dart';

/// One controllable endpoint, paired with the device it belongs to, so the
/// action picker can offer a flat list across all devices.
class _ActionTarget {
  const _ActionTarget(this.device, this.control);
  final MyDevice device;
  final ControlEndpoint control;

  String get key => '${device.id}|${control.topic}';
}

/// Builds or edits an [AutomationRule]: pick when it runs (a time of day, or a
/// sensor crossing a threshold) and what it does (which control, set to what).
class AutomationEditorSheet extends StatefulWidget {
  const AutomationEditorSheet({
    super.key,
    required this.targets,
    required this.sensorSources,
    this.existing,
  });

  /// Devices that have at least one control — the possible action targets.
  final List<MyDevice> targets;

  /// Devices that can supply a sensor reading for a threshold trigger.
  final List<MyDevice> sensorSources;

  final AutomationRule? existing;

  @override
  State<AutomationEditorSheet> createState() => _AutomationEditorSheetState();
}

class _AutomationEditorSheetState extends State<AutomationEditorSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _threshold = TextEditingController(
    text: widget.existing?.threshold?.toString() ?? '',
  );

  late TriggerType _triggerType =
      widget.existing?.triggerType ?? TriggerType.time;
  late TimeOfDay _time = _parseTime(widget.existing?.triggerTime);
  late Set<int> _days = {...?widget.existing?.triggerDays};

  late int? _sourceDeviceId =
      widget.existing?.sourceDeviceId ??
      (widget.sensorSources.isNotEmpty ? widget.sensorSources.first.id : null);
  late String _sensorKey = widget.existing?.sensorKey ?? 'Ambient_Temperature';
  late Comparator _comparator = widget.existing?.comparator ?? Comparator.above;

  late final List<_ActionTarget> _allTargets = [
    for (final d in widget.targets)
      for (final c in d.controls) _ActionTarget(d, c),
  ];

  _ActionTarget? _target;

  /// For a switch action: on or off. For a value action: the number to send.
  bool _actionOn = true;
  late final _actionValue = TextEditingController();

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      for (final t in _allTargets) {
        if (t.device.id == e.actionDeviceId &&
            t.control.topic == e.actionTopic) {
          _target = t;
        }
      }
      if (_target != null && _target!.control.isSwitch) {
        _actionOn = e.actionPayload.trim() == _target!.control.onPayload.trim();
      } else {
        _actionValue.text = e.actionPayload;
      }
    }
    _target ??= _allTargets.isNotEmpty ? _allTargets.first : null;
    if (_actionValue.text.isEmpty &&
        _target != null &&
        !_target!.control.isSwitch) {
      _actionValue.text = _target!.control.min.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _threshold.dispose();
    _actionValue.dispose();
    super.dispose();
  }

  static TimeOfDay _parseTime(String? hhmm) {
    final parts = (hhmm ?? '').split(':');
    if (parts.length == 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null) return TimeOfDay(hour: h, minute: m);
    }
    return const TimeOfDay(hour: 6, minute: 0);
  }

  String get _timeString =>
      '${_time.hour.toString().padLeft(2, '0')}:'
      '${_time.minute.toString().padLeft(2, '0')}';

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final target = _target;
    if (target == null) {
      _snack('Add a switch or value control to a device first.');
      return;
    }
    if (_name.text.trim().isEmpty) {
      _snack('Give the rule a name.');
      return;
    }

    double? threshold;
    if (_triggerType == TriggerType.sensor) {
      threshold = double.tryParse(_threshold.text.trim());
      if (threshold == null) {
        _snack('Enter a numeric threshold.');
        return;
      }
      if (_sourceDeviceId == null) {
        _snack('Choose which device to read the sensor from.');
        return;
      }
    }

    final String payload;
    if (target.control.isSwitch) {
      payload = _actionOn
          ? target.control.onPayload
          : target.control.offPayload;
    } else {
      final v = double.tryParse(_actionValue.text.trim());
      if (v == null) {
        _snack('Enter a numeric value to send.');
        return;
      }
      payload = v.toStringAsFixed(0);
    }

    final rule = AutomationRule(
      id: widget.existing?.id,
      name: _name.text.trim(),
      enabled: widget.existing?.enabled ?? true,
      triggerType: _triggerType,
      triggerTime: _triggerType == TriggerType.time ? _timeString : null,
      triggerDays: _days.toList()..sort(),
      sourceDeviceId: _triggerType == TriggerType.sensor
          ? _sourceDeviceId
          : null,
      sensorKey: _triggerType == TriggerType.sensor ? _sensorKey : null,
      comparator: _triggerType == TriggerType.sensor ? _comparator : null,
      threshold: threshold,
      actionDeviceId: target.device.id,
      actionTopic: target.control.topic,
      actionPayload: payload,
      actionLabel: target.control.label,
    );

    setState(() => _busy = true);
    final ok = await context.read<DevicesCubit>().saveAutomation(rule);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = _target;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.existing == null
                  ? context.tr('add_rule')
                  : context.tr('edit_rule'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Rule name',
                hintText: 'Morning irrigation',
              ),
            ),

            // ── When ──────────────────────────────────────────────────
            const SizedBox(height: 20),
            _SectionLabel(context.tr('when')),
            SegmentedButton<TriggerType>(
              segments: [
                ButtonSegment(
                  value: TriggerType.time,
                  label: Text(context.tr('at_a_time')),
                  icon: const Icon(Icons.access_time),
                ),
                ButtonSegment(
                  value: TriggerType.sensor,
                  label: Text(context.tr('sensor_level')),
                  icon: const Icon(Icons.sensors),
                ),
              ],
              selected: {_triggerType},
              onSelectionChanged: (s) => setState(() => _triggerType = s.first),
            ),
            const SizedBox(height: 12),

            if (_triggerType == TriggerType.time)
              _TimeTriggerFields(
                time: _time,
                timeLabel: _timeString,
                days: _days,
                onPickTime: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (picked != null) setState(() => _time = picked);
                },
                onToggleDay: (d) => setState(() {
                  _days.contains(d) ? _days.remove(d) : _days.add(d);
                }),
              )
            else
              _SensorTriggerFields(
                sources: widget.sensorSources,
                sourceDeviceId: _sourceDeviceId,
                sensorKey: _sensorKey,
                comparator: _comparator,
                thresholdController: _threshold,
                onSource: (v) => setState(() => _sourceDeviceId = v),
                onSensor: (v) => setState(() => _sensorKey = v),
                onComparator: (v) => setState(() => _comparator = v),
              ),

            // ── Then ──────────────────────────────────────────────────
            const SizedBox(height: 20),
            _SectionLabel(context.tr('then')),
            if (_allTargets.isEmpty)
              Text(
                'No controls yet. Add a switch or value control to a device '
                'before creating a rule.',
                style: theme.textTheme.bodySmall,
              )
            else ...[
              DropdownButtonFormField<String>(
                initialValue: target?.key,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Control'),
                items: [
                  for (final t in _allTargets)
                    DropdownMenuItem(
                      value: t.key,
                      child: Text(
                        widget.targets.length > 1
                            ? '${t.control.label} · ${t.device.name}'
                            : t.control.label,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() {
                  _target = _allTargets.firstWhere((t) => t.key == v);
                  if (!_target!.control.isSwitch &&
                      double.tryParse(_actionValue.text) == null) {
                    _actionValue.text = _target!.control.min.toStringAsFixed(0);
                  }
                }),
              ),
              const SizedBox(height: 10),
              if (target != null && target.control.isSwitch)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Turn on'),
                      icon: Icon(Icons.toggle_on),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Turn off'),
                      icon: Icon(Icons.toggle_off_outlined),
                    ),
                  ],
                  selected: {_actionOn},
                  onSelectionChanged: (s) =>
                      setState(() => _actionOn = s.first),
                )
              else if (target != null)
                TextField(
                  controller: _actionValue,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Set value',
                    suffixText: target.control.unit,
                    helperText:
                        'Between ${target.control.min.toStringAsFixed(0)} '
                        'and ${target.control.max.toStringAsFixed(0)}',
                  ),
                ),
            ],

            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy || _allTargets.isEmpty ? null : _save,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('save')),
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('automation_server_time_note'),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        letterSpacing: 1.1,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

class _TimeTriggerFields extends StatelessWidget {
  const _TimeTriggerFields({
    required this.time,
    required this.timeLabel,
    required this.days,
    required this.onPickTime,
    required this.onToggleDay,
  });

  final TimeOfDay time;
  final String timeLabel;
  final Set<int> days;
  final VoidCallback onPickTime;
  final ValueChanged<int> onToggleDay;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: onPickTime,
          icon: const Icon(Icons.schedule),
          label: Text('At $timeLabel'),
        ),
        const SizedBox(height: 10),
        Text(
          days.isEmpty ? 'Every day' : 'On selected days',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (var d = 0; d < kWeekdayLabels.length; d++)
              FilterChip(
                label: Text(kWeekdayLabels[d]),
                selected: days.contains(d),
                onSelected: (_) => onToggleDay(d),
              ),
          ],
        ),
      ],
    );
  }
}

class _SensorTriggerFields extends StatelessWidget {
  const _SensorTriggerFields({
    required this.sources,
    required this.sourceDeviceId,
    required this.sensorKey,
    required this.comparator,
    required this.thresholdController,
    required this.onSource,
    required this.onSensor,
    required this.onComparator,
  });

  final List<MyDevice> sources;
  final int? sourceDeviceId;
  final String sensorKey;
  final Comparator comparator;
  final TextEditingController thresholdController;
  final ValueChanged<int?> onSource;
  final ValueChanged<String> onSensor;
  final ValueChanged<Comparator> onComparator;

  @override
  Widget build(BuildContext context) {
    final meta = SensorMeta.all.where((m) => m.key == sensorKey);
    final unit = meta.isEmpty ? '' : meta.first.unit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sources.length > 1) ...[
          DropdownButtonFormField<int>(
            initialValue: sourceDeviceId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Read sensor from'),
            items: [
              for (final d in sources)
                DropdownMenuItem(value: d.id, child: Text(d.name)),
            ],
            onChanged: onSource,
          ),
          const SizedBox(height: 10),
        ],
        DropdownButtonFormField<String>(
          initialValue: sensorKey,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sensor'),
          items: [
            for (final m in SensorMeta.all)
              DropdownMenuItem(
                value: m.key,
                child: Row(
                  children: [
                    Icon(m.icon, size: 16),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(m.label, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onSensor(v);
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<Comparator>(
                segments: const [
                  ButtonSegment(
                    value: Comparator.above,
                    label: Text('Above'),
                    icon: Icon(Icons.arrow_upward, size: 16),
                  ),
                  ButtonSegment(
                    value: Comparator.below,
                    label: Text('Below'),
                    icon: Icon(Icons.arrow_downward, size: 16),
                  ),
                ],
                selected: {comparator},
                onSelectionChanged: (s) => onComparator(s.first),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 104,
              child: TextField(
                controller: thresholdController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Value',
                  suffixText: unit.isEmpty ? null : unit,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Fires once when the reading crosses the threshold, not repeatedly '
          'while it stays past it.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
