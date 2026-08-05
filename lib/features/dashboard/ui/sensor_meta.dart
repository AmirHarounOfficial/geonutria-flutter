import 'package:flutter/material.dart';

/// Where a reading sits relative to its healthy band.
enum SensorLevel { low, ok, high, unknown }

/// Display metadata for a sensor key returned by `/iot-status`.
class SensorMeta {
  const SensorMeta(
    this.key,
    this.label,
    this.unit,
    this.icon, {
    this.max = 100,
    this.okMin,
    this.okMax,
  });
  final String key;
  final String label;
  final String unit;
  final IconData icon;
  final double max; // for gauge scaling

  /// Healthy band for this reading, when one is meaningful. Used to tell the
  /// user whether a value is fine, not just what it is.
  final double? okMin;
  final double? okMax;

  bool get hasBand => okMin != null && okMax != null;

  /// Where [v] sits relative to the healthy band.
  SensorLevel level(double v) {
    if (!hasBand) return SensorLevel.unknown;
    if (v < okMin!) return SensorLevel.low;
    if (v > okMax!) return SensorLevel.high;
    return SensorLevel.ok;
  }

  /// Ordered list of the sensors we surface, keyed by the backend's field names.
  static const List<SensorMeta> all = [
    SensorMeta(
      'Soil_Moisture',
      'Soil Moisture',
      '%',
      Icons.water_drop,
      max: 100,
      okMin: 30,
      okMax: 70,
    ),
    SensorMeta(
      'Soil_Temperature',
      'Soil Temp',
      '°C',
      Icons.thermostat,
      max: 60,
      okMin: 15,
      okMax: 30,
    ),
    SensorMeta(
      'Ambient_Temperature',
      'Ambient Temp',
      '°C',
      Icons.device_thermostat,
      max: 60,
      okMin: 10,
      okMax: 35,
    ),
    SensorMeta(
      'Humidity',
      'Humidity',
      '%',
      Icons.cloud,
      max: 100,
      okMin: 40,
      okMax: 80,
    ),
    SensorMeta(
      'Soil_pH',
      'Soil pH',
      '',
      Icons.science,
      max: 14,
      okMin: 6.0,
      okMax: 7.5,
    ),
    SensorMeta(
      'Nitrogen_Level',
      'Nitrogen (N)',
      'mg/kg',
      Icons.eco,
      max: 200,
      okMin: 40,
      okMax: 120,
    ),
    SensorMeta(
      'Phosphorus_Level',
      'Phosphorus (P)',
      'mg/kg',
      Icons.eco,
      max: 200,
      okMin: 20,
      okMax: 80,
    ),
    SensorMeta(
      'Potassium_Level',
      'Potassium (K)',
      'mg/kg',
      Icons.eco,
      max: 200,
      okMin: 40,
      okMax: 120,
    ),
    SensorMeta(
      'Electrochemical_Signal',
      'EC',
      'µS/cm',
      Icons.bolt,
      max: 3000,
      okMin: 200,
      okMax: 1500,
    ),
    SensorMeta(
      'Salinity',
      'Salinity',
      'ppt',
      Icons.water,
      max: 100,
      okMin: 0,
      okMax: 4,
    ),
    SensorMeta(
      'TDS',
      'TDS',
      'ppm',
      Icons.opacity,
      max: 2000,
      okMin: 100,
      okMax: 1000,
    ),
    SensorMeta(
      'Light_Intensity',
      'Light',
      'lux',
      Icons.light_mode,
      max: 100000,
    ),
    SensorMeta('Epsilon', 'Epsilon', '', Icons.scatter_plot, max: 100),
  ];
}
