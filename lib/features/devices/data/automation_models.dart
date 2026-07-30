import 'package:equatable/equatable.dart';

/// What starts a rule.
enum TriggerType { time, sensor }

/// How a sensor reading is compared to the threshold.
enum Comparator { above, below }

/// One automation rule: when [triggerType] fires, publish [actionPayload] to
/// [actionTopic] on [actionDeviceId].
///
/// Sensor rules are edge-triggered by the backend — they fire when the reading
/// crosses the threshold, not repeatedly while it stays past it.
class AutomationRule extends Equatable {
  const AutomationRule({
    this.id,
    required this.name,
    this.enabled = true,
    required this.triggerType,
    this.triggerTime,
    this.triggerDays = const [],
    this.sourceDeviceId,
    this.sensorKey,
    this.comparator,
    this.threshold,
    required this.actionDeviceId,
    required this.actionTopic,
    required this.actionPayload,
    this.actionLabel,
    this.lastFiredAt,
    this.lastError,
  });

  final int? id;
  final String name;
  final bool enabled;
  final TriggerType triggerType;

  /// 'HH:MM' in the server's local time.
  final String? triggerTime;

  /// Weekdays the rule runs on, 0 = Monday. Empty means every day.
  final List<int> triggerDays;

  final int? sourceDeviceId;
  final String? sensorKey;
  final Comparator? comparator;
  final double? threshold;

  final int actionDeviceId;
  final String actionTopic;
  final String actionPayload;

  /// The control's label, stored for display so the list doesn't need to
  /// resolve the topic back to a control.
  final String? actionLabel;

  final DateTime? lastFiredAt;
  final String? lastError;

  bool get isTimeTrigger => triggerType == TriggerType.time;
  bool get runsDaily => triggerDays.isEmpty || triggerDays.length == 7;

  factory AutomationRule.fromJson(Map<String, dynamic> j) => AutomationRule(
    id: (j['id'] as num?)?.toInt(),
    name: (j['name'] ?? 'Rule').toString(),
    enabled: _asBool(j['enabled']),
    triggerType: (j['trigger_type'] ?? 'time').toString() == 'sensor'
        ? TriggerType.sensor
        : TriggerType.time,
    triggerTime: j['trigger_time']?.toString(),
    triggerDays: _days(j['trigger_days']),
    sourceDeviceId: (j['source_device_id'] as num?)?.toInt(),
    sensorKey: j['sensor_key']?.toString(),
    comparator: switch (j['comparator']?.toString()) {
      'above' => Comparator.above,
      'below' => Comparator.below,
      _ => null,
    },
    threshold: (j['threshold'] as num?)?.toDouble(),
    actionDeviceId: (j['action_device_id'] as num?)?.toInt() ?? 0,
    actionTopic: (j['action_topic'] ?? '').toString(),
    actionPayload: (j['action_payload'] ?? '').toString(),
    actionLabel: j['action_label']?.toString(),
    lastFiredAt: DateTime.tryParse(j['last_fired_at']?.toString() ?? ''),
    lastError: j['last_error']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'enabled': enabled,
    'trigger_type': triggerType.name,
    'trigger_time': isTimeTrigger ? triggerTime : null,
    'trigger_days': isTimeTrigger && !runsDaily ? triggerDays.join(',') : null,
    'source_device_id': isTimeTrigger ? null : sourceDeviceId,
    'sensor_key': isTimeTrigger ? null : sensorKey,
    'comparator': isTimeTrigger ? null : comparator?.name,
    'threshold': isTimeTrigger ? null : threshold,
    'action_device_id': actionDeviceId,
    'action_topic': actionTopic,
    'action_payload': actionPayload,
    'action_label': actionLabel,
  };

  AutomationRule copyWith({
    String? name,
    bool? enabled,
    TriggerType? triggerType,
    String? triggerTime,
    List<int>? triggerDays,
    int? sourceDeviceId,
    String? sensorKey,
    Comparator? comparator,
    double? threshold,
    int? actionDeviceId,
    String? actionTopic,
    String? actionPayload,
    String? actionLabel,
  }) => AutomationRule(
    id: id,
    name: name ?? this.name,
    enabled: enabled ?? this.enabled,
    triggerType: triggerType ?? this.triggerType,
    triggerTime: triggerTime ?? this.triggerTime,
    triggerDays: triggerDays ?? this.triggerDays,
    sourceDeviceId: sourceDeviceId ?? this.sourceDeviceId,
    sensorKey: sensorKey ?? this.sensorKey,
    comparator: comparator ?? this.comparator,
    threshold: threshold ?? this.threshold,
    actionDeviceId: actionDeviceId ?? this.actionDeviceId,
    actionTopic: actionTopic ?? this.actionTopic,
    actionPayload: actionPayload ?? this.actionPayload,
    actionLabel: actionLabel ?? this.actionLabel,
    lastFiredAt: lastFiredAt,
    lastError: lastError,
  );

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  static List<int> _days(dynamic v) {
    if (v == null) return const [];
    return v
        .toString()
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();
  }

  @override
  List<Object?> get props => [
    id,
    name,
    enabled,
    triggerType,
    triggerTime,
    triggerDays,
    sourceDeviceId,
    sensorKey,
    comparator,
    threshold,
    actionDeviceId,
    actionTopic,
    actionPayload,
    lastFiredAt,
    lastError,
  ];
}

/// Weekday labels, index 0 = Monday to match the backend's convention.
const List<String> kWeekdayLabels = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];
