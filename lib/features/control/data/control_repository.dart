import '../../../core/network/api_client.dart';
import 'control_models.dart';

/// Talks to the backend's `/control` router — the same endpoints the web
/// dashboard uses for actuators and automation schedules.
///
/// Auth is the `user_id` credential, passed as a query parameter on GET and
/// DELETE and in the body on POST/PUT, matching the deployed API.
class ControlRepository {
  ControlRepository(this._api);

  final ApiClient _api;

  int get _uid => _api.userId ?? 0;

  // ── Actuators ──────────────────────────────────────────────────────────
  Future<List<Actuator>> actuators() async {
    final data = await _api.get('/control/actuators', query: _api.authQuery());
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Actuator.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  /// Last-known state for every actuator, keyed by actuator id.
  Future<Map<int, ActuatorLiveState>> actuatorStates() async {
    final data = await _api.get(
      '/control/actuators/states/all',
      query: _api.authQuery(),
    );
    final states = (data is Map) ? data['states'] : null;
    if (states is! Map) return const {};
    final out = <int, ActuatorLiveState>{};
    for (final entry in states.entries) {
      final id = int.tryParse('${entry.key}');
      if (id == null || entry.value is! Map) continue;
      out[id] = ActuatorLiveState.fromJson(
        (entry.value as Map).cast<String, dynamic>(),
      );
    }
    return out;
  }

  /// Sends a command. [action] is one of `on`, `off`, `set_rgb`,
  /// `set_brightness`, `set_value`.
  Future<void> command(
    int actuatorId, {
    required String action,
    Object? value,
    int? durationMinutes,
  }) async {
    await _api.post(
      '/control/actuators/$actuatorId/command',
      body: {
        'user_id': _uid,
        'action': action,
        if (value != null) 'value': value,
        if (durationMinutes != null) 'duration_minutes': durationMinutes,
      },
    );
  }

  // ── Schedules ──────────────────────────────────────────────────────────
  Future<List<Schedule>> schedules() async {
    final data = await _api.get('/control/schedules', query: _api.authQuery());
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Schedule.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Future<void> createSchedule(Schedule s) async {
    await _api.post(
      '/control/schedules',
      body: {'user_id': _uid, ...s.toJson()},
    );
  }

  Future<void> updateSchedule(int id, Schedule s) async {
    await _api.put(
      '/control/schedules/$id',
      body: {'user_id': _uid, ...s.toJson()},
    );
  }

  /// Flips `is_active`. The server owns the new value — it toggles whatever it
  /// currently holds rather than accepting one from the client.
  Future<void> toggleSchedule(int id) async {
    await _api.post('/control/schedules/$id/toggle', query: _api.authQuery());
  }

  Future<void> deleteSchedule(int id) async {
    await _api.delete('/control/schedules/$id', query: _api.authQuery());
  }

  // ── Threshold sources ──────────────────────────────────────────────────
  Future<List<SensorDevice>> sensorDevices() async {
    final data = await _api.get(
      '/control/sensor-devices',
      query: _api.authQuery(),
    );
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => SensorDevice.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }
}
