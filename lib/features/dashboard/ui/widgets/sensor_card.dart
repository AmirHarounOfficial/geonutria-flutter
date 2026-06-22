import 'package:flutter/material.dart';

import '../sensor_meta.dart';

/// Compact sensor tile: icon, value + unit, label, and a thin progress bar
/// indicating the value within its expected range.
class SensorCard extends StatelessWidget {
  const SensorCard({super.key, required this.meta, required this.value});

  final SensorMeta meta;
  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = (value / meta.max).clamp(0.0, 1.0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(meta.icon, size: 18, color: scheme.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    meta.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _fmt(value),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                if (meta.unit.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Text(meta.unit,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v.abs() >= 1000) return v.toStringAsFixed(0);
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}
