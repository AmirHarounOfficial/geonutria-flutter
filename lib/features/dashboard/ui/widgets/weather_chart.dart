import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/iot_models.dart';

class _WMetric {
  const _WMetric(this.label, this.selector, this.unit, this.description);
  final String label;
  final double? Function(WeatherPoint) selector;
  final String unit;

  /// What the number actually means — the scale or the period it covers.
  /// Without this a "0" is ambiguous: no rain, or no reading?
  final String description;

  String get axisLabel => unit.isEmpty ? label : '$label ($unit)';
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
    _WMetric('Temp', (p) => p.temperatureC, '°C', 'Air temperature'),
    _WMetric('Humidity', (p) => p.humidity, '%', 'Relative humidity, 0–100%'),
    _WMetric(
      'Rain',
      (p) => p.precipitation,
      'mm',
      'Total rainfall in each interval. 0 mm means no rain was recorded.',
    ),
    _WMetric(
      'Cloud',
      (p) => p.cloud,
      '%',
      'Share of sky covered, 0–100%. 0% means clear sky.',
    ),
    _WMetric('Wind', (p) => p.wind, 'km/h', 'Wind speed'),
    _WMetric('Solar', (p) => p.solar, 'W/m²', 'Solar radiation'),
  ];

  int _selected = 0;

  static String _fmtValue(double v) {
    final a = v.abs();
    if (a >= 10000) return '${(v / 1000).toStringAsFixed(0)}k';
    if (a >= 100) return v.toStringAsFixed(0);
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final metric = _metrics[_selected];
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final history = <FlSpot>[];
    final forecast = <FlSpot>[];
    final indexToLabel = <int, String>{};
    var reported = 0;

    for (var i = 0; i < widget.points.length; i++) {
      final p = widget.points[i];
      final v = metric.selector(p);
      indexToLabel[i] = p.label;
      if (v == null) continue;
      reported++;
      (p.isForecast ? forecast : history).add(FlSpot(i.toDouble(), v));
    }
    // Bridge the gap so the forecast line connects to the last history point.
    if (history.isNotEmpty && forecast.isNotEmpty) {
      forecast.insert(0, history.last);
    }

    final all = [...history, ...forecast];
    double minY = 0, maxY = 1, yInterval = 1;
    if (all.isNotEmpty) {
      minY = all.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      maxY = all.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      if (maxY - minY < 1e-6) {
        // A genuinely flat series — rain sitting at 0, say — still needs a
        // band, otherwise the line is pinned to the axis and unreadable.
        final pad = maxY.abs() < 1 ? 1.0 : maxY.abs() * 0.1;
        minY -= pad;
        maxY += pad;
      } else {
        final pad = (maxY - minY) * 0.1;
        minY -= pad;
        maxY += pad;
      }
      // Rain and cloud can't go negative; don't imply they can.
      if (metric.label == 'Rain' || metric.label == 'Cloud') {
        if (minY < 0) minY = 0;
      }
      yInterval = (maxY - minY) / 4;
      if (yInterval <= 0) yInterval = 1;
    }

    final xInterval = widget.points.length <= 1
        ? 1.0
        : (widget.points.length / 4).ceilToDouble().clamp(1, 1e9).toDouble();

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
        const SizedBox(height: 6),
        Text(
          metric.axisLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          metric.description,
          style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
        ),
        const SizedBox(height: 8),
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
          child: reported == 0
              // Distinct from a measured zero: this source sent nothing at all
              // for this metric.
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '${metric.label} was not reported for this period.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: LineChart(
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: yInterval,
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 46,
                            interval: yInterval,
                            getTitlesWidget: (value, meta) => Padding(
                              padding: const EdgeInsetsDirectional.only(end: 6),
                              child: Text(
                                _fmtValue(value),
                                style: theme.textTheme.labelSmall,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: xInterval,
                            getTitlesWidget: (value, meta) {
                              final label = indexToLabel[value.round()];
                              if (label == null || label.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  label,
                                  style: theme.textTheme.labelSmall,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (touched) => touched.map((t) {
                            final when = indexToLabel[t.x.round()] ?? '';
                            return LineTooltipItem(
                              '${_fmtValue(t.y)} ${metric.unit}\n$when',
                              theme.textTheme.labelSmall ?? const TextStyle(),
                            );
                          }).toList(),
                        ),
                      ),
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
