import 'package:flutter/material.dart';

/// Display metadata for a sensor key returned by `/iot-status`.
class SensorMeta {
  const SensorMeta(this.key, this.label, this.unit, this.icon, {this.max = 100});
  final String key;
  final String label;
  final String unit;
  final IconData icon;
  final double max; // for gauge scaling

  /// Ordered list of the sensors we surface, keyed by the backend's field names.
  static const List<SensorMeta> all = [
    SensorMeta('Soil_Moisture', 'Soil Moisture', '%', Icons.water_drop, max: 100),
    SensorMeta('Soil_Temperature', 'Soil Temp', '°C', Icons.thermostat, max: 60),
    SensorMeta('Ambient_Temperature', 'Ambient Temp', '°C', Icons.device_thermostat, max: 60),
    SensorMeta('Humidity', 'Humidity', '%', Icons.cloud, max: 100),
    SensorMeta('Soil_pH', 'Soil pH', '', Icons.science, max: 14),
    SensorMeta('Nitrogen_Level', 'Nitrogen (N)', 'mg/kg', Icons.eco, max: 200),
    SensorMeta('Phosphorus_Level', 'Phosphorus (P)', 'mg/kg', Icons.eco, max: 200),
    SensorMeta('Potassium_Level', 'Potassium (K)', 'mg/kg', Icons.eco, max: 200),
    SensorMeta('Electrochemical_Signal', 'EC', 'µS/cm', Icons.bolt, max: 3000),
    SensorMeta('Salinity', 'Salinity', 'ppt', Icons.water, max: 100),
    SensorMeta('TDS', 'TDS', 'ppm', Icons.opacity, max: 2000),
    SensorMeta('Light_Intensity', 'Light', 'lux', Icons.light_mode, max: 100000),
    SensorMeta('Epsilon', 'Epsilon', '', Icons.scatter_plot, max: 100),
  ];
}
