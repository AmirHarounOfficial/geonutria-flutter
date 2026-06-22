import 'package:equatable/equatable.dart';

/// An IoT device from `GET /devices`.
class Device extends Equatable {
  const Device({
    required this.id,
    required this.name,
    this.farmId,
    this.location,
    this.latitude,
    this.longitude,
  });

  final int id;
  final String name;
  final int? farmId;
  final String? location;
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  factory Device.fromJson(Map<String, dynamic> j) => Device(
        id: (j['id'] as num).toInt(),
        name: (j['device_name'] ?? j['name'] ?? 'Device ${j['id']}').toString(),
        farmId: (j['farm_id'] as num?)?.toInt(),
        location: (j['installed_location'] ?? j['location'])?.toString(),
        latitude: _toD(j['latitude']),
        longitude: _toD(j['longitude']),
      );

  @override
  List<Object?> get props => [id, name, farmId, latitude, longitude];
}

/// AI health diagnosis block shared by `/iot-status` and `/manual-diagnosis`.
class Diagnosis extends Equatable {
  const Diagnosis({
    required this.status,
    required this.probabilities,
    required this.features,
  });

  final String status; // Healthy / Moderate Stress / High Stress / No Live Data
  final Map<String, double> probabilities; // Healthy / Moderate / High
  final Map<String, double> features; // feature importances

  factory Diagnosis.fromJson(Map<String, dynamic> j) => Diagnosis(
        status: (j['status'] ?? 'Unknown').toString(),
        probabilities: _toDoubleMap(j['probabilities']),
        features: _toDoubleMap(j['features']),
      );

  static const empty = Diagnosis(
    status: 'Unknown',
    probabilities: {},
    features: {},
  );

  @override
  List<Object?> get props => [status, probabilities, features];
}

/// Response of `GET /iot-status`.
class IotStatus extends Equatable {
  const IotStatus({
    required this.mqttStatus,
    required this.sensors,
    required this.diagnosis,
    this.dashboardUrl,
  });

  final String mqttStatus;
  final Map<String, double> sensors; // Soil_Moisture, Ambient_Temperature, ...
  final Diagnosis diagnosis;
  final String? dashboardUrl;

  bool get hasLiveData => diagnosis.status != 'No Live Data' && sensors.isNotEmpty;

  factory IotStatus.fromJson(Map<String, dynamic> j) => IotStatus(
        mqttStatus: (j['mqtt_status'] ?? 'unknown').toString(),
        sensors: _toDoubleMap(j['sensors']),
        diagnosis: Diagnosis.fromJson(
            (j['ai_diagnosis'] as Map?)?.cast<String, dynamic>() ?? const {}),
        dashboardUrl: j['dashboard_url']?.toString(),
      );

  @override
  List<Object?> get props => [mqttStatus, sensors, diagnosis];
}

/// A single historical reading from `GET /iot-history/{id}`.
class HistoryPoint extends Equatable {
  const HistoryPoint({
    required this.timestamp,
    this.nitrogen,
    this.phosphorus,
    this.potassium,
    this.temperature,
    this.humidity,
    this.ph,
    this.moisture,
    this.soilTemp,
    this.ec,
    this.salinity,
    this.tds,
    this.epsilon,
  });

  final String timestamp;
  final double? nitrogen;
  final double? phosphorus;
  final double? potassium;
  final double? temperature;
  final double? humidity;
  final double? ph;
  final double? moisture;
  final double? soilTemp;
  final double? ec;
  final double? salinity;
  final double? tds;
  final double? epsilon;

  factory HistoryPoint.fromJson(Map<String, dynamic> j) => HistoryPoint(
        timestamp: (j['timestamp'] ?? '').toString(),
        nitrogen: _toD(j['nitrogen']),
        phosphorus: _toD(j['phosphorus']),
        potassium: _toD(j['potassium']),
        temperature: _toD(j['temperature']),
        humidity: _toD(j['humidity']),
        ph: _toD(j['ph']),
        moisture: _toD(j['moisture']),
        soilTemp: _toD(j['soil_temp']),
        ec: _toD(j['ec']),
        salinity: _toD(j['salinity']),
        tds: _toD(j['tds']),
        epsilon: _toD(j['epsilon']),
      );

  @override
  List<Object?> get props => [timestamp];
}

/// A macro-weather point from `GET /weather-charts/{id}`.
class WeatherPoint extends Equatable {
  const WeatherPoint({
    required this.label,
    required this.isForecast,
    this.temperatureC,
    this.humidity,
    this.precipitation,
    this.cloud,
    this.wind,
    this.solar,
  });

  final String label;
  final bool isForecast;
  final double? temperatureC;
  final double? humidity;
  final double? precipitation;
  final double? cloud;
  final double? wind;
  final double? solar;

  factory WeatherPoint.fromJson(Map<String, dynamic> j) => WeatherPoint(
        label: (j['label'] ?? '').toString(),
        isForecast: j['is_forecast'] == true,
        temperatureC: _toD(j['temperature_c']),
        humidity: _toD(j['relative_humidity']),
        precipitation: _toD(j['precipitation_mm']),
        cloud: _toD(j['cloud_cover_pct']),
        wind: _toD(j['wind_speed_kmh']),
        solar: _toD(j['solar_radiation_wm2']),
      );

  @override
  List<Object?> get props => [label, isForecast];
}

double? _toD(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse('$v');
}

Map<String, double> _toDoubleMap(dynamic v) {
  if (v is! Map) return {};
  final out = <String, double>{};
  v.forEach((k, val) {
    final d = _toD(val);
    if (d != null) out['$k'] = d;
  });
  return out;
}
