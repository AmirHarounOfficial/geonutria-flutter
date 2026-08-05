import 'package:flutter/material.dart';

import '../sensor_meta.dart';

/// Sensor tile for the dashboard.
///
/// A bare number tells a farmer very little — 6.2 pH is fine, 6.2% moisture is
/// not. So each card shows where the reading sits against its healthy band,
/// with the band drawn on the scale and the verdict spelled out in words as
/// well as colour.
class SensorCard extends StatelessWidget {
  const SensorCard({super.key, required this.meta, required this.value});

  final SensorMeta meta;
  final double value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final level = meta.level(value);
    final accent = _levelColour(level, scheme);

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(meta.icon, size: 15, color: accent),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    meta.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
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
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                    letterSpacing: -0.5,
                  ),
                ),
                if (meta.unit.isNotEmpty) ...[
                  const SizedBox(width: 3),
                  Text(
                    meta.unit,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            _RangeBar(meta: meta, value: value, accent: accent),
            if (level != SensorLevel.unknown) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(_levelIcon(level), size: 12, color: accent),
                  const SizedBox(width: 4),
                  Text(
                    _levelLabel(level),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _levelLabel(SensorLevel l) => switch (l) {
    SensorLevel.low => 'Below range',
    SensorLevel.high => 'Above range',
    SensorLevel.ok => 'In range',
    SensorLevel.unknown => '',
  };

  static IconData _levelIcon(SensorLevel l) => switch (l) {
    SensorLevel.low => Icons.arrow_downward,
    SensorLevel.high => Icons.arrow_upward,
    _ => Icons.check_circle_outline,
  };

  static Color _levelColour(SensorLevel l, ColorScheme s) => switch (l) {
    SensorLevel.low => const Color(
      0xFF3B82F6,
    ), // low reads as cold, not alarming
    SensorLevel.high => const Color(0xFFE0A21A),
    SensorLevel.ok => const Color(0xFF4F7357),
    SensorLevel.unknown => s.primary,
  };

  String _fmt(double v) {
    if (v.abs() >= 1000) return v.toStringAsFixed(0);
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }
}

/// The scale, with the healthy band shaded and a marker at the reading.
class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.meta,
    required this.value,
    required this.accent,
  });

  final SensorMeta meta;
  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = (value / meta.max).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final bandStart = meta.hasBand
            ? (meta.okMin! / meta.max).clamp(0.0, 1.0)
            : 0.0;
        final bandEnd = meta.hasBand
            ? (meta.okMax! / meta.max).clamp(0.0, 1.0)
            : 0.0;

        return SizedBox(
          height: 10,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Track
              Positioned(
                left: 0,
                right: 0,
                top: 3,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Healthy band
              if (meta.hasBand)
                Positioned(
                  left: bandStart * w,
                  width: ((bandEnd - bandStart) * w).clamp(2.0, w),
                  top: 3,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F7357).withValues(alpha: 0.32),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              // Reading marker, clamped so it never sits half outside the card
              Positioned(
                left: (ratio * w - 5).clamp(0.0, w - 10),
                top: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: scheme.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
