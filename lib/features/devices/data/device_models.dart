import 'package:equatable/equatable.dart';

/// A controllable MQTT endpoint on a device — either an on/off switch or a
/// numeric value the app can publish.
class ControlEndpoint extends Equatable {
  const ControlEndpoint({
    required this.label,
    required this.topic,
    this.type = 'switch',
    this.onPayload = '1',
    this.offPayload = '0',
    this.min = 0,
    this.max = 100,
    this.unit,
    this.stateTopic,
  });

  final String label;
  final String topic; // published to (command)
  final String type; // 'switch' | 'value'
  final String onPayload;
  final String offPayload;
  final double min;
  final double max;
  final String? unit;

  /// Topic the device publishes its actual state on. When set, the UI shows
  /// the reported state instead of assuming the last command took effect.
  final String? stateTopic;

  bool get isSwitch => type == 'switch';

  bool get hasStateFeedback => stateTopic != null && stateTopic!.isNotEmpty;

  /// Interprets a raw payload from [stateTopic] as on/off.
  ///
  /// Matches [onPayload]/[offPayload] first, then falls back to common
  /// truthy spellings so a device reporting "ON" or "true" still resolves
  /// when the command payload is "1".
  bool? parseOnState(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v == onPayload.trim().toLowerCase()) return true;
    if (v == offPayload.trim().toLowerCase()) return false;
    if (['1', 'on', 'true', 'open', 'yes'].contains(v)) return true;
    if (['0', 'off', 'false', 'closed', 'no'].contains(v)) return false;
    final n = double.tryParse(v);
    if (n != null) return n != 0;
    return null;
  }

  factory ControlEndpoint.fromJson(Map<String, dynamic> j) => ControlEndpoint(
    label: (j['label'] ?? j['topic'] ?? '').toString(),
    topic: (j['topic'] ?? '').toString(),
    type: (j['type'] ?? 'switch').toString(),
    onPayload: (j['on_payload'] ?? '1').toString(),
    offPayload: (j['off_payload'] ?? '0').toString(),
    min: (j['min'] as num?)?.toDouble() ?? 0,
    max: (j['max'] as num?)?.toDouble() ?? 100,
    unit: j['unit']?.toString(),
    stateTopic: j['state_topic']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'label': label,
    'topic': topic,
    'type': type,
    'on_payload': onPayload,
    'off_payload': offPayload,
    'min': min,
    'max': max,
    if (unit != null) 'unit': unit,
    if (stateTopic != null) 'state_topic': stateTopic,
  };

  ControlEndpoint copyWith({
    String? label,
    String? topic,
    String? type,
    String? onPayload,
    String? offPayload,
    double? min,
    double? max,
    String? unit,
    String? stateTopic,
  }) => ControlEndpoint(
    label: label ?? this.label,
    topic: topic ?? this.topic,
    type: type ?? this.type,
    onPayload: onPayload ?? this.onPayload,
    offPayload: offPayload ?? this.offPayload,
    min: min ?? this.min,
    max: max ?? this.max,
    unit: unit ?? this.unit,
    stateTopic: stateTopic ?? this.stateTopic,
  );

  @override
  List<Object?> get props => [
    label,
    topic,
    type,
    onPayload,
    offPayload,
    min,
    max,
    unit,
    stateTopic,
  ];
}

/// Freshness of a device's data, shown as a status indicator.
///
/// Colour alone would fail colour-blind users and anyone glancing quickly, so
/// each value is always rendered with its label beside it.
enum DeviceHealth { online, stale, offline, never }

/// A device bound to the user via the My Devices feature.
class MyDevice extends Equatable {
  const MyDevice({
    required this.id,
    required this.name,
    this.location,
    this.latitude,
    this.longitude,
    this.mqttTopics = const [],
    this.controls = const [],
    this.otaTopic,
    this.firmwareVersion,
    this.farmId,
    this.lastReadingAt,
    this.healthKnown = false,
  });

  final int id;
  final String name;
  final String? location;
  final double? latitude;
  final double? longitude;
  final List<String> mqttTopics;
  final List<ControlEndpoint> controls;
  final String? otaTopic;
  final String? firmwareVersion;
  final int? farmId;

  /// When this device last stored a reading, or null if it never has.
  final DateTime? lastReadingAt;

  /// Whether the server reported freshness at all.
  ///
  /// The deployed backend does not send `last_reading_at`, and an absent field
  /// is not the same as "never reported" — claiming a device is offline when
  /// we simply were not told would be worse than staying quiet. When this is
  /// false the UI omits the status indicator entirely.
  final bool healthKnown;

  bool get hasLocation => latitude != null && longitude != null;

  /// How fresh the device's data is, for the status indicator in the list.
  DeviceHealth get health {
    final t = lastReadingAt;
    if (t == null) return DeviceHealth.never;
    final age = DateTime.now().difference(t);
    if (age.inMinutes <= 15) return DeviceHealth.online;
    if (age.inHours <= 24) return DeviceHealth.stale;
    return DeviceHealth.offline;
  }

  /// Short human phrasing of [lastReadingAt] — "4 min ago", "3 days ago".
  String get lastSeenLabel {
    final t = lastReadingAt;
    if (t == null) return 'never reported';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  factory MyDevice.fromJson(Map<String, dynamic> j) => MyDevice(
    id: (j['id'] as num).toInt(),
    name: (j['device_name'] ?? j['name'] ?? 'Device ${j['id']}').toString(),
    location: (j['installed_location'] ?? j['location'])?.toString(),
    latitude: (j['latitude'] as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    mqttTopics: _stringList(j['mqtt_topics']),
    controls: (j['control_topics'] is List)
        ? (j['control_topics'] as List)
              .whereType<Map>()
              .map((e) => ControlEndpoint.fromJson(e.cast<String, dynamic>()))
              .toList()
        : const [],
    otaTopic: j['ota_topic']?.toString(),
    firmwareVersion: j['firmware_version']?.toString(),
    farmId: (j['farm_id'] as num?)?.toInt(),
    lastReadingAt: DateTime.tryParse(j['last_reading_at']?.toString() ?? ''),
    healthKnown: j.containsKey('last_reading_at'),
  );

  static List<String> _stringList(dynamic v) {
    if (v is List) return v.map((e) => '$e').toList();
    return const [];
  }

  @override
  List<Object?> get props => [
    id,
    name,
    mqttTopics,
    controls,
    otaTopic,
    firmwareVersion,
  ];
}
