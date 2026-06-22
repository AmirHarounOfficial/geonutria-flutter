import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/iot_models.dart';

class _WMetric {
  const _WMetric(this.label, this.selector, this.unit);
  final String label;
  final double? Function(WeatherPoint) selector;
  final String unit;
}

/// Macro-weather chart: history + forecast, with the forecast portion drawn in
/// a lighter dashed style.
class WeatherChart extends StatefulWidget {
  const WeatherChart({super.key, required this.points});
  final List<WeatherPoint> points;

  @override
  State<WeatherChart> createState() => _WeatherChartState();
}

class _WeatherChartState extends State<WeatherChart> {
  static final _metrics = <_WMetric>[
    _WMetric('Temp', (p) => p.temperatureC, '°C'),
    _WMetric('Humidity', (p) => p.humidity, '%'),
    _WMetric('Rain', (p) => p.precipitation, 'mm'),
    _WMetric('Cloud', (p) => p.cloud, '%'),
    _WMetric('Wind', (p) => p.wind, 'km/h'),
    _WMetric('Solar', (p) => p.solar, 'W/m²'),
  ];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final metric = _metrics[_selected];
    final history = <FlSpot>[];
    final forecast = <FlSpot>[];
    for (var i = 0; i < widget.points.length; i++) {
      final p = widget.points[i];
      final v = metric.selector(p);
      if (v == null) continue;
      (p.isForecast ? forecast : history).add(FlSpot(i.toDouble(), v));
    }
    // Bridge the gap so the forecast line connects to the last history point.
    if (history.isNotEmpty && forecast.isNotEmpty) {
      forecast.insert(0, history.last);
    }
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _metrics.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) => ChoiceChip(
              label: Text(_metrics[i].label),
              selected: i == _selected,
              onSelected: (_) => setState(() => _selected = i),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            _Legend(color: scheme.primary, label: 'History'),
            const SizedBox(width: 16),
            _Legend(color: scheme.tertiary, label: 'Forecast'),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: (history.isEmpty && forecast.isEmpty)
              ? const Center(child: Text('No data'))
              : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: true, reservedSize: 40)),
                      bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      if (history.isNotEmpty)
                        LineChartBarData(
                          spots: history,
                          isCurved: true,
                          barWidth: 2.5,
                          color: scheme.primary,
                          dotData: const FlDotData(show: false),
                        ),
                      if (forecast.isNotEmpty)
                        LineChartBarData(
                          spots: forecast,
                          isCurved: true,
                          barWidth: 2.5,
                          color: scheme.tertiary,
                          dashArray: [6, 4],
                          dotData: const FlDotData(show: false),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 14, height: 4, color: color),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
