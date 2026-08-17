import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../bloc/control_cubit.dart';
import '../../data/control_models.dart';

/// Opens the builder, carrying the cubit into the sheet's own context.
void openScheduleEditor(BuildContext context, Schedule? existing) {
  final cubit = context.read<ControlCubit>();
  cubit.loadSensorDevices();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: ScheduleEditorSheet(existing: existing),
    ),
  );
}

/// Builds or edits an automation schedule.
///
/// The backend stores a cron expression, but a time picker and day chips are
/// what a farmer can actually reason about, so the visual selection is
/// compiled to cron on save and parsed back on edit — the same compilation the
/// web dashboard uses, so a rule made on either client reads correctly on the
/// other.
class ScheduleEditorSheet extends StatefulWidget {
  const ScheduleEditorSheet({super.key, this.existing});
  final Schedule? existing;

  @override
  State<ScheduleEditorSheet> createState() => _ScheduleEditorSheetState();
}

class _ScheduleEditorSheetState extends State<ScheduleEditorSheet> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _threshold = TextEditingController(
    text: widget.existing?.threshold?.toString() ?? '',
  );
  late final _duration = TextEditingController(
    text: widget.existing?.durationMinutes?.toString() ?? '',
  );

  late TriggerType _trigger =
      widget.existing?.triggerType == TriggerType.threshold
      ? TriggerType.threshold
      : TriggerType.cron;

  late TimeOfDay _time;
  late Set<String> _days;

  int? _actuatorId;
  int? _sourceDeviceId;
  late String _sensor = widget.existing?.sensor ?? 'soil_moisture';
  late String _operator = widget.existing?.operator ?? '<';
  late String _action = widget.existing?.action ?? 'on';

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final parsed = parseCron(widget.existing?.cronExpression);
    _time = TimeOfDay(hour: parsed.hour, minute: parsed.minute);
    _days = {...parsed.days};
    _actuatorId = widget.existing?.actuatorId;
    _sourceDeviceId = widget.existing?.sourceDeviceId;
  }

  @override
  void dispose() {
    _name.dispose();
    _threshold.dispose();
    _duration.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? _thresholdError;
  String? _durationError;

  (double, double, String) _getMetricRange(String sensor) {
    switch (sensor.toLowerCase()) {
      case 'soil_moisture':
      case 'humidity':
        return (0.0, 100.0, '0 to 100%');
      case 'soil_temp':
      case 'ambient_temp':
      case 'temperature':
        return (-50.0, 100.0, '-50 to 100°C');
      case 'soil_ph':
      case 'ph':
        return (0.0, 14.0, '0 to 14');
      case 'ec':
        return (0.0, 20.0, '0 to 20 dS/m');
      case 'nitrogen':
      case 'phosphorus':
      case 'potassium':
        return (0.0, 1000.0, '0 to 1000 mg/kg');
      default:
        return (-10000.0, 10000.0, 'valid numeric value');
    }
  }

  void _validateThreshold([String? text]) {
    if (_trigger != TriggerType.threshold) {
      setState(() => _thresholdError = null);
      return;
    }
    final raw = (text ?? _threshold.text).trim();
    if (raw.isEmpty) {
      setState(() => _thresholdError = 'Enter a numeric threshold');
      return;
    }
    final val = double.tryParse(raw);
    if (val == null) {
      setState(() => _thresholdError = 'Invalid number format');
      return;
    }
    final (min, max, label) = _getMetricRange(_sensor);
    if (val < min || val > max) {
      setState(() => _thresholdError = 'Value must be between $label');
      return;
    }
    setState(() => _thresholdError = null);
  }

  void _validateDuration([String? text]) {
    final raw = (text ?? _duration.text).trim();
    if (raw.isEmpty) {
      setState(() => _durationError = null);
      return;
    }
    final val = int.tryParse(raw);
    if (val == null || val < 1 || val > 1440) {
      setState(() => _durationError = 'Enter a duration between 1 and 1440 minutes');
      return;
    }
    setState(() => _durationError = null);
  }

  Future<void> _save() async {
    final cubit = context.read<ControlCubit>();
    final actuatorId = _actuatorId;
    if (actuatorId == null) {
      _snack('Choose which device the rule should act on.');
      return;
    }

    _validateThreshold();
    _validateDuration();

    if (_thresholdError != null || _durationError != null) {
      _snack(_thresholdError ?? _durationError ?? 'Please fix input errors.');
      return;
    }

    double? threshold;
    if (_trigger == TriggerType.threshold) {
      threshold = double.tryParse(_threshold.text.trim());
      if (threshold == null) {
        _snack('Enter a numeric threshold.');
        return;
      }
      if (_sourceDeviceId == null) {
        _snack('Choose which sensor device to read from.');
        return;
      }
    }

    final duration = int.tryParse(_duration.text.trim());
    if (_duration.text.trim().isNotEmpty && duration == null) {
      _snack('Duration must be a whole number of minutes.');
      return;
    }

    final schedule = Schedule(
      id: widget.existing?.id,
      actuatorId: actuatorId,
      name: _name.text.trim().isEmpty
          ? (_trigger == TriggerType.cron ? 'Timed rule' : 'Sensor rule')
          : _name.text.trim(),
      triggerType: _trigger,
      cronExpression: _trigger == TriggerType.cron
          ? compileCron(hour: _time.hour, minute: _time.minute, days: _days)
          : null,
      thresholdConfig: _trigger == TriggerType.threshold
          ? {
              'sensor': _sensor,
              'operator': _operator,
              'value': threshold,
              'device_id': _sourceDeviceId,
            }
          : null,
      actionPayload: {
        'action': _action,
        // Only meaningful when switching on — the engine turns it off again
        // after the delay.
        if (_action == 'on' && duration != null) 'duration_minutes': duration,
      },
      isActive: widget.existing?.isActive ?? true,
    );

    setState(() => _busy = true);
    final ok = await cubit.saveSchedule(schedule);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<ControlCubit, ControlState>(
      builder: (context, state) {
        final actuators = state.actuators;
        _actuatorId ??= actuators.isNotEmpty ? actuators.first.id : null;

        final sources = state.sensorDevices;
        if (_trigger == TriggerType.threshold && _sourceDeviceId == null) {
          _sourceDeviceId = sources.isNotEmpty ? sources.first.id : null;
        }

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

                // ── When ────────────────────────────────────────────────
                const SizedBox(height: 20),
                _Label(context.tr('when')),
                SegmentedButton<TriggerType>(
                  segments: [
                    ButtonSegment(
                      value: TriggerType.cron,
                      label: Text(context.tr('at_a_time')),
                      icon: const Icon(Icons.access_time),
                    ),
                    ButtonSegment(
                      value: TriggerType.threshold,
                      label: Text(context.tr('sensor_level')),
                      icon: const Icon(Icons.sensors),
                    ),
                  ],
                  selected: {_trigger},
                  onSelectionChanged: (s) => setState(() => _trigger = s.first),
                ),
                const SizedBox(height: 12),

                if (_trigger == TriggerType.cron)
                  _TimeFields(
                    time: _time,
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
                  _ThresholdFields(
                    sources: sources,
                    sourceDeviceId: _sourceDeviceId,
                    sensor: _sensor,
                    operator: _operator,
                    controller: _threshold,
                    errorText: _thresholdError,
                    onChanged: _validateThreshold,
                    onSource: (v) => setState(() => _sourceDeviceId = v),
                    onSensor: (v) {
                      setState(() => _sensor = v);
                      _validateThreshold();
                    },
                    onOperator: (v) => setState(() => _operator = v),
                  ),

                // ── Then ────────────────────────────────────────────────
                const SizedBox(height: 20),
                _Label(context.tr('then')),
                if (actuators.isEmpty)
                  Text(
                    'No controllable devices on this account yet. An '
                    'administrator adds them.',
                    style: theme.textTheme.bodySmall,
                  )
                else ...[
                  DropdownButtonFormField<int>(
                    initialValue: _actuatorId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Device'),
                    items: [
                      for (final a in actuators)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(a.name, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    onChanged: (v) => setState(() => _actuatorId = v),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'on',
                        label: Text('Turn on'),
                        icon: Icon(Icons.toggle_on),
                      ),
                      ButtonSegment(
                        value: 'off',
                        label: Text('Turn off'),
                        icon: Icon(Icons.toggle_off_outlined),
                      ),
                    ],
                    selected: {_action},
                    onSelectionChanged: (s) =>
                        setState(() => _action = s.first),
                  ),
                  if (_action == 'on') ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _duration,
                      keyboardType: TextInputType.number,
                      onChanged: _validateDuration,
                      decoration: InputDecoration(
                        labelText: 'Run for (minutes, optional)',
                        helperText: 'Leave blank to leave it on',
                        errorText: _durationError,
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy || actuators.isEmpty ? null : _save,
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
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
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

class _TimeFields extends StatelessWidget {
  const _TimeFields({
    required this.time,
    required this.days,
    required this.onPickTime,
    required this.onToggleDay,
  });

  final TimeOfDay time;
  final Set<String> days;
  final VoidCallback onPickTime;
  final ValueChanged<String> onToggleDay;

  @override
  Widget build(BuildContext context) {
    final label =
        '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: onPickTime,
          icon: const Icon(Icons.schedule),
          label: Text('At $label'),
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
            for (final d in kScheduleDays)
              FilterChip(
                label: Text(d),
                selected: days.contains(d),
                onSelected: (_) => onToggleDay(d),
              ),
          ],
        ),
      ],
    );
  }
}

class _ThresholdFields extends StatelessWidget {
  const _ThresholdFields({
    required this.sources,
    required this.sourceDeviceId,
    required this.sensor,
    required this.operator,
    required this.controller,
    required this.onSource,
    required this.onSensor,
    required this.onOperator,
    this.errorText,
    this.onChanged,
  });

  final List<SensorDevice> sources;
  final int? sourceDeviceId;
  final String sensor;
  final String operator;
  final TextEditingController controller;
  final ValueChanged<int?> onSource;
  final ValueChanged<String> onSensor;
  final ValueChanged<String> onOperator;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    // Offer the metrics the chosen device advertises; fall back to the
    // standard set when the list has not loaded.
    final device = sources.where((d) => d.id == sourceDeviceId);
    final metrics = device.isNotEmpty && device.first.metrics.isNotEmpty
        ? device.first.metrics
        : kStandardMetrics.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sources.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'No sensor devices available to read from.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else ...[
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
          initialValue: metrics.contains(sensor) ? sensor : metrics.first,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Sensor'),
          items: [
            for (final m in metrics)
              DropdownMenuItem(
                value: m,
                child: Text(
                  kStandardMetrics[m] ?? m,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (v) {
            if (v != null) onSensor(v);
          },
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<String>(
                initialValue: operator,
                decoration: const InputDecoration(labelText: 'Is'),
                items: const [
                  DropdownMenuItem(value: '<', child: Text('below')),
                  DropdownMenuItem(value: '<=', child: Text('at or below')),
                  DropdownMenuItem(value: '>', child: Text('above')),
                  DropdownMenuItem(value: '>=', child: Text('at or above')),
                  DropdownMenuItem(value: '==', child: Text('exactly')),
                ],
                onChanged: (v) {
                  if (v != null) onOperator(v);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Value',
                  isDense: true,
                  errorText: errorText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Checked as readings arrive, with a 10-minute cooldown between '
          'firings so a fluctuating reading cannot retrigger it repeatedly.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
