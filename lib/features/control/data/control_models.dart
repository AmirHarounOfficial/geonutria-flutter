import 'package:equatable/equatable.dart';

/// Actuator kinds the backend's `actuators.device_type` enum allows.
enum ActuatorType { pump, led, rgb, valve, fan, other }

ActuatorType actuatorTypeFrom(String? raw) => switch (raw) {
  'Pump' => ActuatorType.pump,
  'LED' => ActuatorType.led,
  'RGB' => ActuatorType.rgb,
  'Valve' => ActuatorType.valve,
  'Fan' => ActuatorType.fan,
  _ => ActuatorType.other,
};

/// A controllable device from `/control/actuators`.
///
/// This is the model the deployed backend and the web dashboard both use.
/// Actuators are created by administrators (`/admin/actuators`) and shared with
/// users through `user_actuator_access`.
class Actuator extends Equatable {
  const Actuator({
    required this.id,
    required this.name,
    required this.type,
    this.state = const {},
    this.publishTopic,
    this.subscribeTopic,
    this.location,
    this.farmId,
  });

  final int id;
  final String name;
  final ActuatorType type;

  /// Server-side view of the actuator, e.g.
  /// `{"power": "on", "brightness": 80, "r": 255, "g": 0, "b": 128}`.
  final Map<String, dynamic> state;

  final String? publishTopic;
  final String? subscribeTopic;
  final String? location;
  final int? farmId;

  bool get supportsBrightness =>
      type == ActuatorType.led || type == ActuatorType.rgb;
  bool get supportsColour => type == ActuatorType.rgb;

  int get brightness => (state['brightness'] as num?)?.toInt() ?? 100;

  ({int r, int g, int b}) get colour => (
    r: (state['r'] as num?)?.toInt() ?? 255,
    g: (state['g'] as num?)?.toInt() ?? 200,
    b: (state['b'] as num?)?.toInt() ?? 100,
  );

  factory Actuator.fromJson(Map<String, dynamic> j) => Actuator(
    id: (j['id'] as num).toInt(),
    name: (j['device_name'] ?? 'Actuator ${j['id']}').toString(),
    type: actuatorTypeFrom(j['device_type']?.toString()),
    state: _asMap(j['state']),
    publishTopic: j['mqtt_publish_topic']?.toString(),
    subscribeTopic: j['mqtt_subscribe_topic']?.toString(),
    location: j['installed_location']?.toString(),
    farmId: (j['farm_id'] as num?)?.toInt(),
  );

  static Map<String, dynamic> _asMap(dynamic v) {
    if (v is Map) return v.cast<String, dynamic>();
    return const {};
  }

  @override
  List<Object?> get props => [id, name, type, state, publishTopic];
}

/// Live view of one actuator from `/control/actuators/states/all`.
class ActuatorLiveState extends Equatable {
  const ActuatorLiveState({this.dbState = const {}, this.mqttFeedback});

  final Map<String, dynamic> dbState;

  /// Raw payload last heard on the actuator's subscribe topic, if any.
  final String? mqttFeedback;

  /// Whether the actuator reads as on.
  ///
  /// Deliberately mirrors the web dashboard's rule so both clients agree:
  /// the stored power flag, OR an affirmative MQTT payload.
  bool get isOn {
    final power = dbState['power']?.toString().toLowerCase();
    if (power == 'on') return true;
    final fb = mqttFeedback?.trim().toLowerCase();
    return fb == 'on' || fb == '1';
  }

  factory ActuatorLiveState.fromJson(Map<String, dynamic> j) =>
      ActuatorLiveState(
        dbState: (j['db_state'] is Map)
            ? (j['db_state'] as Map).cast<String, dynamic>()
            : const {},
        mqttFeedback: j['mqtt_feedback']?.toString(),
      );

  @override
  List<Object?> get props => [dbState, mqttFeedback];
}

/// What starts a schedule. Matches the backend enum.
enum TriggerType { cron, threshold, aiSuggested }

TriggerType triggerTypeFrom(String? raw) => switch (raw) {
  'threshold' => TriggerType.threshold,
  'ai_suggested' => TriggerType.aiSuggested,
  _ => TriggerType.cron,
};

String triggerTypeTo(TriggerType t) => switch (t) {
  TriggerType.threshold => 'threshold',
  TriggerType.aiSuggested => 'ai_suggested',
  TriggerType.cron => 'cron',
};

/// The five comparisons the automation engine understands.
const kThresholdOperators = ['>', '<', '>=', '<=', '=='];

/// Sensor metrics the backend exposes for threshold rules
/// (`STANDARD_METRICS` in control.py).
const kStandardMetrics = <String, String>{
  'soil_moisture': 'Soil Moisture',
  'soil_temp': 'Soil Temperature',
  'soil_ph': 'Soil pH',
  'nitrogen_n': 'Nitrogen (N)',
  'phosphorus_p': 'Phosphorus (P)',
  'potassium_k': 'Potassium (K)',
  'salinity': 'Salinity',
  'ec': 'EC Signal',
  'ambient_temp': 'Ambient Temperature',
  'ambient_humidity': 'Humidity',
};

/// A sensor device offered as a threshold source (`/control/sensor-devices`).
class SensorDevice extends Equatable {
  const SensorDevice({
    required this.id,
    required this.name,
    this.metrics = const [],
  });

  final int id;
  final String name;
  final List<String> metrics;

  factory SensorDevice.fromJson(Map<String, dynamic> j) => SensorDevice(
    id: (j['id'] as num).toInt(),
    name: (j['device_name'] ?? 'Device ${j['id']}').toString(),
    metrics: (j['metrics'] is List)
        ? (j['metrics'] as List).map((e) => '$e').toList()
        : const [],
  );

  @override
  List<Object?> get props => [id, name, metrics];
}

/// An automation schedule from `/control/schedules`.
class Schedule extends Equatable {
  const Schedule({
    this.id,
    required this.actuatorId,
    this.name,
    required this.triggerType,
    this.cronExpression,
    this.thresholdConfig,
    this.actionPayload = const {'action': 'on'},
    this.isActive = true,
    this.aiExplanation,
    this.actuatorName,
    this.actuatorType,
  });

  final int? id;
  final int actuatorId;
  final String? name;
  final TriggerType triggerType;

  /// Standard 5-field cron, e.g. `30 6 * * 1,3,5`.
  final String? cronExpression;

  /// `{sensor, operator, value, device_id}` for threshold triggers.
  final Map<String, dynamic>? thresholdConfig;

  /// `{action: 'on'|'off', duration_minutes?: int}`.
  final Map<String, dynamic> actionPayload;

  final bool isActive;
  final String? aiExplanation;

  /// Joined from the actuators table by the list endpoint.
  final String? actuatorName;
  final String? actuatorType;

  String get action => (actionPayload['action'] ?? 'on').toString();
  int? get durationMinutes =>
      (actionPayload['duration_minutes'] as num?)?.toInt();

  String? get sensor => thresholdConfig?['sensor']?.toString();
  String? get operator => thresholdConfig?['operator']?.toString();
  double? get threshold => (thresholdConfig?['value'] as num?)?.toDouble();
  int? get sourceDeviceId => (thresholdConfig?['device_id'] as num?)?.toInt();

  factory Schedule.fromJson(Map<String, dynamic> j) => Schedule(
    id: (j['id'] as num?)?.toInt(),
    actuatorId: (j['actuator_id'] as num?)?.toInt() ?? 0,
    name: j['schedule_name']?.toString(),
    triggerType: triggerTypeFrom(j['trigger_type']?.toString()),
    cronExpression: j['cron_expression']?.toString(),
    thresholdConfig: _asMapOrNull(j['threshold_config']),
    actionPayload: _asMapOrNull(j['action_payload']) ?? const {'action': 'on'},
    isActive: _asBool(j['is_active']),
    aiExplanation: j['ai_explanation']?.toString(),
    actuatorName: j['actuator_name']?.toString(),
    actuatorType: j['actuator_type']?.toString(),
  );

  /// Body for create/update. `user_id` is added by the repository.
  Map<String, dynamic> toJson() => {
    'actuator_id': actuatorId,
    'schedule_name': name,
    'trigger_type': triggerTypeTo(triggerType),
    'is_active': isActive,
    'action_payload': actionPayload,
    if (triggerType == TriggerType.cron) 'cron_expression': cronExpression,
    if (triggerType == TriggerType.threshold)
      'threshold_config': thresholdConfig,
    if (aiExplanation != null) 'ai_explanation': aiExplanation,
  };

  Schedule copyWith({bool? isActive}) => Schedule(
    id: id,
    actuatorId: actuatorId,
    name: name,
    triggerType: triggerType,
    cronExpression: cronExpression,
    thresholdConfig: thresholdConfig,
    actionPayload: actionPayload,
    isActive: isActive ?? this.isActive,
    aiExplanation: aiExplanation,
    actuatorName: actuatorName,
    actuatorType: actuatorType,
  );

  static Map<String, dynamic>? _asMapOrNull(dynamic v) {
    if (v is Map) return v.cast<String, dynamic>();
    return null;
  }

  static bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    final s = v?.toString().toLowerCase();
    return s == 'true' || s == '1';
  }

  @override
  List<Object?> get props => [
    id,
    actuatorId,
    name,
    triggerType,
    cronExpression,
    thresholdConfig,
    actionPayload,
    isActive,
  ];
}

/// Weekday chips, ordered Mon-first for display.
const kScheduleDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Cron day-of-week numbers. Sunday is 0, matching the web builder.
const _cronDayNumber = {
  'Mon': 1,
  'Tue': 2,
  'Wed': 3,
  'Thu': 4,
  'Fri': 5,
  'Sat': 6,
  'Sun': 0,
};

/// Builds the same cron string the web dashboard's `compileCron` produces, so a
/// rule created on either client reads identically on the other.
///
/// Empty [days] means every day (`*`).
String compileCron({
  required int hour,
  required int minute,
  Set<String> days = const {},
}) {
  if (days.isEmpty) return '$minute $hour * * *';
  final nums = days.map((d) => _cronDayNumber[d]).whereType<int>().toList()
    ..sort();
  return '$minute $hour * * ${nums.join(',')}';
}

/// Inverse of [compileCron] for editing an existing schedule.
({int hour, int minute, Set<String> days}) parseCron(String? cron) {
  const fallback = (hour: 8, minute: 0, days: <String>{});
  if (cron == null || cron.trim().isEmpty) return fallback;
  final parts = cron.trim().split(RegExp(r'\s+'));
  if (parts.length < 5) return fallback;

  final minute = int.tryParse(parts[0]) ?? 0;
  final hour = int.tryParse(parts[1]) ?? 8;
  final dow = parts[4];
  if (dow == '*') return (hour: hour, minute: minute, days: <String>{});

  final reverse = {for (final e in _cronDayNumber.entries) e.value: e.key};
  final days = <String>{
    for (final d in dow.split(','))
      if (reverse[int.tryParse(d.trim())] != null)
        reverse[int.tryParse(d.trim())]!,
  };
  return (hour: hour, minute: minute, days: days);
}
