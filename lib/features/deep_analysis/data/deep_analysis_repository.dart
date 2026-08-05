import '../../../core/network/api_client.dart';
import '../../dashboard/data/iot_models.dart';
import 'analysis_context.dart';

/// Talks to `/v1/rag-diagnosis` — the deep diagnosis the web dashboard runs.
///
/// The endpoint takes the live sensor readings, the weather around the device
/// and the farm context, and streams back a markdown report token by token.
class DeepAnalysisRepository {
  DeepAnalysisRepository(this._api);

  final ApiClient _api;

  /// Streams the report. Reasoning tokens arrive tagged so the UI can keep the
  /// model's working separate from its conclusion.
  Stream<ChatToken> diagnose({
    required Map<String, double> sensors,
    required Map<String, dynamic> weather,
    required AnalysisContext context,
    required String lang,
  }) {
    return _api.streamChatTokens(
      '/v1/rag-diagnosis',
      body: {
        'sensor_data': sensors,
        'weather_data': weather,
        'context': context.toJson(),
        'lang': lang,
      },
    );
  }

  /// The most recent observed weather for a device, shaped the way the prompt
  /// builder expects (it just lists the entries, so the keys are what the
  /// model reads).
  ///
  /// Best-effort: weather enriches the diagnosis but is not required, and the
  /// backend prints "(None)" for an empty block. A device without a location
  /// or a failing lookup should not cost the user the analysis.
  Future<Map<String, dynamic>> latestWeather(int deviceId) async {
    try {
      final points = await _api.get(
        '/weather-charts/$deviceId',
        query: _api.authQuery({'interval': 'Days'}),
      );
      final list = (points is Map) ? points['data'] : null;
      if (list is! List) return const {};

      final observed = list
          .whereType<Map>()
          .map((e) => WeatherPoint.fromJson(e.cast<String, dynamic>()))
          .where((p) => !p.isForecast)
          .toList();
      if (observed.isEmpty) return const {};

      final w = observed.last;
      return {
        if (w.temperatureC != null) 'temperature': w.temperatureC,
        if (w.humidity != null) 'humidity': w.humidity,
        if (w.precipitation != null) 'precipitation': w.precipitation,
        if (w.cloud != null) 'clouds': w.cloud,
        if (w.wind != null) 'wind': w.wind,
        if (w.solar != null) 'solar': w.solar,
      };
    } catch (_) {
      return const {};
    }
  }
}
