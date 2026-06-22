import '../../../core/network/api_client.dart';
import 'iot_models.dart';

/// Wraps the IoT endpoints (all at root). Auth is via the `user_id` query param,
/// injected through [ApiClient.authQuery].
class IotRepository {
  IotRepository(this._api);

  final ApiClient _api;

  /// `GET /devices?user_id=`. Returns the devices the user can access.
  Future<List<Device>> getDevices() async {
    final data = await _api.get('/devices', query: _api.authQuery());
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Device.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    // Backend returns {status:error,...} on failure.
    return [];
  }

  /// `GET /iot-status?user_id=&device_id=` (costs 5 credits).
  Future<IotStatus> getStatus(int deviceId) async {
    final data = await _api.get('/iot-status',
        query: _api.authQuery({'device_id': deviceId}));
    return IotStatus.fromJson((data as Map).cast<String, dynamic>());
  }

  /// `GET /iot/refresh/{id}?user_id=` (costs 1 credit). Forces a sync + weather
  /// enrichment and returns the freshest sensor values.
  Future<Map<String, double>> refresh(int deviceId) async {
    final data =
        await _api.get('/iot/refresh/$deviceId', query: _api.authQuery());
    final map = (data as Map).cast<String, dynamic>();
    final sensors = map['data'];
    if (sensors is Map) {
      final out = <String, double>{};
      sensors.forEach((k, v) {
        final d = v is num ? v.toDouble() : double.tryParse('$v');
        if (d != null) out['$k'] = d;
      });
      return out;
    }
    return {};
  }

  /// `GET /iot-history/{id}?user_id=&limit=&interval=` (costs 5 credits).
  Future<List<HistoryPoint>> getHistory(
    int deviceId, {
    int limit = 50,
    String interval = 'Live',
  }) async {
    final data = await _api.get('/iot-history/$deviceId',
        query: _api.authQuery({'limit': limit, 'interval': interval}));
    final map = (data as Map).cast<String, dynamic>();
    final list = map['data'];
    if (list is List) {
      // Backend returns DESC; reverse to chronological for charts.
      return list
          .whereType<Map>()
          .map((e) => HistoryPoint.fromJson(e.cast<String, dynamic>()))
          .toList()
          .reversed
          .toList();
    }
    return [];
  }

  /// `POST /manual-diagnosis` (costs 5 credits).
  Future<Diagnosis> manualDiagnosis({
    required int userId,
    required double moisture,
    required double ambientTemp,
    required double soilTemp,
    required double humidity,
    required double ph,
    required double nitrogen,
    required double phosphorus,
    required double potassium,
    required double ec,
  }) async {
    final data = await _api.post('/manual-diagnosis', body: {
      'user_id': userId,
      'moisture': moisture,
      'ambient_temp': ambientTemp,
      'soil_temp': soilTemp,
      'humidity': humidity,
      'ph': ph,
      'nitrogen': nitrogen,
      'phosphorus': phosphorus,
      'potassium': potassium,
      'ec': ec,
    });
    final map = (data as Map).cast<String, dynamic>();
    return Diagnosis.fromJson(
        (map['ai_diagnosis'] as Map?)?.cast<String, dynamic>() ?? const {});
  }

  /// `GET /weather-charts/{id}?interval=Days|Weeks|Months&user_id=`.
  Future<List<WeatherPoint>> getWeatherCharts(
    int deviceId, {
    String interval = 'Days',
  }) async {
    final data = await _api.get('/weather-charts/$deviceId',
        query: _api.authQuery({'interval': interval}));
    final map = (data as Map).cast<String, dynamic>();
    final list = map['data'];
    if (list is List) {
      return list
          .whereType<Map>()
          .map((e) => WeatherPoint.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }
}
