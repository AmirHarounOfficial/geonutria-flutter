import 'package:flutter/material.dart';

import '../../../../core/config/app_colors.dart';
import '../../data/iot_models.dart';

/// Renders the AI health diagnosis: a colored status chip plus the
/// Healthy/Moderate/High probability breakdown.
class DiagnosisCard extends StatelessWidget {
  const DiagnosisCard({super.key, required this.diagnosis, this.title});

  final Diagnosis diagnosis;
  final String? title;

  Color _statusColor() {
    final s = diagnosis.status.toLowerCase();
    if (s.contains('healthy')) return AppColors.success;
    if (s.contains('moderate')) return AppColors.warning;
    if (s.contains('high')) return AppColors.danger;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    final probs = diagnosis.probabilities;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.health_and_safety, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title ?? 'AI Health Diagnosis',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    diagnosis.status,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (probs.isNotEmpty) ...[
              const SizedBox(height: 16),
              _ProbRow('Healthy', probs['Healthy'] ?? 0, AppColors.success),
              _ProbRow('Moderate', probs['Moderate'] ?? 0, AppColors.warning),
              _ProbRow('High Stress', probs['High'] ?? 0, AppColors.danger),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProbRow extends StatelessWidget {
  const _ProbRow(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value.clamp(0.0, 1.0),
                minHeight: 8,
                color: color,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 44,
            child: Text('${(value * 100).toStringAsFixed(0)}%',
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
