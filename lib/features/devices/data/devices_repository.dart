import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'automation_models.dart';
import 'device_models.dart';

/// Talks to the backend `/my-devices` router. Auth is the `user_id` credential
/// (query for GET/DELETE, body field for POST/PUT).
class DevicesRepository {
  DevicesRepository(this._api);

  final ApiClient _api;

  int get _uid => _api.userId ?? 0;

  Future<List<MyDevice>> list() async {
    final data = await _api.get('/my-devices', query: _api.authQuery());
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => MyDevice.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  Future<int> bind({
    required String name,
    required List<String> mqttTopics,
    List<ControlEndpoint> controls = const [],
    String? otaTopic,
    String? location,
    double? latitude,
    double? longitude,
    int? farmId,
  }) async {
    final data = await _api.post(
      '/my-devices/bind',
      body: {
        'user_id': _uid,
        'device_name': name,
        'mqtt_topics': mqttTopics,
        'control_topics': [for (final c in controls) c.toJson()],
        'ota_topic': otaTopic,
        'installed_location': location,
        'latitude': latitude,
        'longitude': longitude,
        'farm_id': farmId,
      },
    );
    return ((data as Map)['device_id'] as num?)?.toInt() ?? 0;
  }

  Future<void> update(
    int deviceId, {
    String? name,
    String? location,
    double? latitude,
    double? longitude,
    List<String>? mqttTopics,
    List<ControlEndpoint>? controls,
    String? otaTopic,
  }) async {
    await _api.put(
      '/my-devices/$deviceId',
      body: {
        'user_id': _uid,
        if (name != null) 'device_name': name,
        if (location != null) 'installed_location': location,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (mqttTopics != null) 'mqtt_topics': mqttTopics,
        if (controls != null)
          'control_topics': [for (final c in controls) c.toJson()],
        if (otaTopic != null) 'ota_topic': otaTopic,
      },
    );
  }

  /// Last-known payload for each control state topic, keyed by topic.
  /// Topics the device has never published on are absent.
  Future<Map<String, String>> controlStates() async {
    final data = await _api.get('/my-devices/states', query: _api.authQuery());
    final states = (data is Map) ? data['states'] : null;
    if (states is Map) {
      return {for (final e in states.entries) '${e.key}': '${e.value}'};
    }
    return {};
  }

  Future<void> unbind(int deviceId) async {
    await _api.delete('/my-devices/$deviceId', query: _api.authQuery());
  }

  // ── Automations ────────────────────────────────────────────────────────
  Future<List<AutomationRule>> automations() async {
    final data = await _api.get(
      '/my-devices/automations',
      query: _api.authQuery(),
    );
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => AutomationRule.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  Future<void> createAutomation(AutomationRule rule) async {
    await _api.post(
      '/my-devices/automations',
      body: {'user_id': _uid, ...rule.toJson()},
    );
  }

  Future<void> updateAutomation(int id, AutomationRule rule) async {
    await _api.put(
      '/my-devices/automations/$id',
      body: {'user_id': _uid, ...rule.toJson()},
    );
  }

  Future<void> setAutomationEnabled(int id, bool enabled) async {
    await _api.patch(
      '/my-devices/automations/$id/enabled',
      body: {'user_id': _uid, 'enabled': enabled},
    );
  }

  Future<void> deleteAutomation(int id) async {
    await _api.delete('/my-devices/automations/$id', query: _api.authQuery());
  }

  /// Publish a control command to one of the device's registered topics.
  Future<void> publish(
    int deviceId,
    String topic,
    String payload, {
    bool retain = false,
  }) async {
    await _api.post(
      '/my-devices/$deviceId/publish',
      body: {
        'user_id': _uid,
        'topic': topic,
        'payload': payload,
        'retain': retain,
      },
    );
  }

  /// Upload a firmware `.bin` and trigger the OTA command.
  Future<String> pushFirmware(
    int deviceId, {
    required List<int> bytes,
    required String fileName,
    required String version,
    String? otaTopic,
  }) async {
    final data = await _api.upload(
      '/my-devices/$deviceId/firmware',
      files: {'file': MultipartFile.fromBytes(bytes, filename: fileName)},
      fields: {
        'user_id': _uid,
        'version': version,
        if (otaTopic != null) 'ota_topic': otaTopic,
      },
    );
    return (data as Map)['version']?.toString() ?? version;
  }
}
