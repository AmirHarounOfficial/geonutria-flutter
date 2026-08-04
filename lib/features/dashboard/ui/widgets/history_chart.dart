import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../data/iot_models.dart';

/// Selectable metric for the history chart, with the unit it is measured in.
class _Metric {
  const _Metric(this.label, this.unit, this.selector);
  final String label;
  final String unit;
  final double? Function(HistoryPoint) selector;

  String get axisLabel => unit.isEmpty ? label : '$label ($unit)';
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
    _Metric('Moisture', '%', (p) => p.moisture),
    _Metric('Soil Temp', '°C', (p) => p.soilTemp),
    _Metric('Temp', '°C', (p) => p.temperature),
    _Metric('Humidity', '%', (p) => p.humidity),
    _Metric('pH', '', (p) => p.ph),
    _Metric('N', 'mg/kg', (p) => p.nitrogen),
    _Metric('P', 'mg/kg', (p) => p.phosphorus),
    _Metric('K', 'mg/kg', (p) => p.potassium),
    _Metric('EC', 'µS/cm', (p) => p.ec),
  ];

  int _selected = 0;

  /// Compact axis value: no trailing decimals on whole numbers, and large
  /// values abbreviated, so labels stay narrow enough not to collide.
  static String _fmtValue(double v) {
    final a = v.abs();
    if (a >= 10000) return '${(v / 1000).toStringAsFixed(0)}k';
    if (a >= 100) return v.toStringAsFixed(0);
    if (a >= 10) return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
    return v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
  }

  /// Best-effort time label from the backend's timestamp string.
  /// Falls back to the raw tail of the string when it will not parse, which
  /// is still more useful than no label at all.
  static String _fmtTime(String raw) {
    final t = DateTime.tryParse(raw);
    if (t != null) {
      final hh = t.hour.toString().padLeft(2, '0');
      final mm = t.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    final s = raw.trim();
    if (s.length >= 16 && s.contains(' ')) return s.substring(11, 16);
    return s.length > 5 ? s.substring(s.length - 5) : s;
  }

  @override
  Widget build(BuildContext context) {
    final metric = _metrics[_selected];
    final theme = Theme.of(context);

    final spots = <FlSpot>[];
    final indexToLabel = <int, String>{};
    for (var i = 0; i < widget.points.length; i++) {
      final v = metric.selector(widget.points[i]);
      if (v != null) {
        spots.add(FlSpot(i.toDouble(), v));
        indexToLabel[i] = _fmtTime(widget.points[i].timestamp);
      }
    }

    // Pad the value range so the line never sits flat on the axis, and derive
    // a tick interval from it — fl_chart's default packs labels together and
    // they overlap on a narrow screen.
    double minY = 0, maxY = 1, yInterval = 1;
    if (spots.isNotEmpty) {
      minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
      maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
      if (maxY - minY < 1e-6) {
        // A flat series still needs a visible band around it.
        final pad = maxY.abs() < 1 ? 1.0 : maxY.abs() * 0.1;
        minY -= pad;
        maxY += pad;
      } else {
        final pad = (maxY - minY) * 0.1;
        minY -= pad;
        maxY += pad;
      }
      yInterval = (maxY - minY) / 4;
      if (yInterval <= 0) yInterval = 1;
    }

    // Aim for ~4 time labels regardless of how many points came back.
    final xInterval = spots.length <= 1
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
        const SizedBox(height: 4),
        Text(
          metric.axisLabel,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 240,
          child: spots.isEmpty
              ? Center(
                  child: Text(
                    'No ${metric.label} readings in this range',
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : Padding(
                  // Room for the last time label so it isn't clipped.
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
                              if (label == null) return const SizedBox.shrink();
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
                            final unit = metric.unit.isEmpty
                                ? ''
                                : ' ${metric.unit}';
                            return LineTooltipItem(
                              '${_fmtValue(t.y)}$unit\n$when',
                              theme.textTheme.labelSmall ?? const TextStyle(),
                            );
                          }).toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          barWidth: 2.5,
                          color: theme.colorScheme.primary,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.12,
                            ),
                          ),
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
