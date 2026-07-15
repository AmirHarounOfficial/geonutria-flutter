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
  });

  final String label;
  final String topic;
  final String type; // 'switch' | 'value'
  final String onPayload;
  final String offPayload;
  final double min;
  final double max;
  final String? unit;

  bool get isSwitch => type == 'switch';

  factory ControlEndpoint.fromJson(Map<String, dynamic> j) => ControlEndpoint(
        label: (j['label'] ?? j['topic'] ?? '').toString(),
        topic: (j['topic'] ?? '').toString(),
        type: (j['type'] ?? 'switch').toString(),
        onPayload: (j['on_payload'] ?? '1').toString(),
        offPayload: (j['off_payload'] ?? '0').toString(),
        min: (j['min'] as num?)?.toDouble() ?? 0,
        max: (j['max'] as num?)?.toDouble() ?? 100,
        unit: j['unit']?.toString(),
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
  }) =>
      ControlEndpoint(
        label: label ?? this.label,
        topic: topic ?? this.topic,
        type: type ?? this.type,
        onPayload: onPayload ?? this.onPayload,
        offPayload: offPayload ?? this.offPayload,
        min: min ?? this.min,
        max: max ?? this.max,
        unit: unit ?? this.unit,
      );

  @override
  List<Object?> get props => [label, topic, type, onPayload, offPayload, min, max, unit];
}

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

  bool get hasLocation => latitude != null && longitude != null;

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
      );

  static List<String> _stringList(dynamic v) {
    if (v is List) return v.map((e) => '$e').toList();
    return const [];
  }

  @override
  List<Object?> get props => [id, name, mqttTopics, controls, otaTopic, firmwareVersion];
}
