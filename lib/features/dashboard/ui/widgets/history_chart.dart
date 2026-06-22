import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/iot_models.dart';

/// Selectable metric for the history chart.
class _Metric {
  const _Metric(this.label, this.selector);
  final String label;
  final double? Function(HistoryPoint) selector;
}

/// Time-series line chart for historical readings, with a metric chooser.
class HistoryChart extends StatefulWidget {
  const HistoryChart({super.key, required this.points});
  final List<HistoryPoint> points;

  @override
  State<HistoryChart> createState() => _HistoryChartState();
}

class _HistoryChartState extends State<HistoryChart> {
  static final _metrics = <_Metric>[
    _Metric('Moisture', (p) => p.moisture),
    _Metric('Soil Temp', (p) => p.soilTemp),
    _Metric('Temp', (p) => p.temperature),
    _Metric('Humidity', (p) => p.humidity),
    _Metric('pH', (p) => p.ph),
    _Metric('N', (p) => p.nitrogen),
    _Metric('P', (p) => p.phosphorus),
    _Metric('K', (p) => p.potassium),
    _Metric('EC', (p) => p.ec),
  ];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final metric = _metrics[_selected];
    final spots = <FlSpot>[];
    for (var i = 0; i < widget.points.length; i++) {
      final v = metric.selector(widget.points[i]);
      if (v != null) spots.add(FlSpot(i.toDouble(), v));
    }

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
        const SizedBox(height: 12),
        SizedBox(
          height: 240,
          child: spots.isEmpty
              ? const Center(child: Text('No values for this metric'))
              : LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                      ),
                      bottomTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        barWidth: 2.5,
                        color: Theme.of(context).colorScheme.primary,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
