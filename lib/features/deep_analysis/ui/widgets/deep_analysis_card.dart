import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../bloc/deep_analysis_cubit.dart';
import '../deep_analysis_sheet.dart';
import '../farm_context_sheet.dart';

/// Entry point for the deep diagnosis on the dashboard's Live tab.
///
/// The web runs this from a button in the page header; here it is a card so
/// the farm context it depends on is visible at the point of use — an analysis
/// run against the wrong crop is worse than no analysis.
class DeepAnalysisCard extends StatelessWidget {
  const DeepAnalysisCard({
    super.key,
    required this.deviceId,
    required this.sensors,
    required this.enabled,
  });

  final int deviceId;
  final Map<String, double> sensors;

  /// False when the device has no live readings — there is nothing to diagnose
  /// and the call would still cost the user a credit.
  final bool enabled;

  void _run(BuildContext context) {
    final cubit = context.read<DeepAnalysisCubit>();
    final lang = context.locale.languageCode == 'ar' ? 'ar' : 'en';
    cubit.run(deviceId: deviceId, sensors: sensors, lang: lang);
    DeepAnalysisSheet.show(
      context,
      cubit,
      onRerun: () =>
          cubit.run(deviceId: deviceId, sensors: sensors, lang: lang),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<DeepAnalysisCubit, DeepAnalysisState>(
      builder: (context, state) {
        final ctx = state.context;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.biotech_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('deep_analysis'),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: context.tr('farm_context'),
                      icon: const Icon(Icons.tune, size: 20),
                      onPressed: () => FarmContextSheet.show(
                        context,
                        context.read<DeepAnalysisCubit>(),
                      ),
                    ),
                  ],
                ),
                Text(
                  context.tr('deep_analysis_desc'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 12),
                if (ctx.isEmpty)
                  // The backend substitutes defaults for a blank context and
                  // says so in the report; saying it here too is what makes the
                  // difference between a tailored and a generic answer visible
                  // before the user spends a credit.
                  _ContextHint(
                    onEdit: () => FarmContextSheet.show(
                      context,
                      context.read<DeepAnalysisCubit>(),
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (ctx.cropType.isNotEmpty)
                        _Chip(
                          icon: Icons.grass_outlined,
                          label: context.tr('ctx_${ctx.cropType}'),
                        ),
                      if (ctx.cropVariety.isNotEmpty)
                        _Chip(icon: Icons.spa_outlined, label: ctx.cropVariety),
                      if (ctx.season.isNotEmpty)
                        _Chip(
                          icon: Icons.calendar_today_outlined,
                          label: context.tr('ctx_${ctx.season}'),
                        ),
                      if (ctx.soilType.isNotEmpty)
                        _Chip(
                          icon: Icons.terrain_outlined,
                          label: context.tr('ctx_${ctx.soilType}'),
                        ),
                      if (ctx.irrigationType.isNotEmpty)
                        _Chip(
                          icon: Icons.water_drop_outlined,
                          label: context.tr('ctx_${ctx.irrigationType}'),
                        ),
                      if (ctx.location.isNotEmpty)
                        _Chip(
                          icon: Icons.place_outlined,
                          label: ctx.location,
                        ),
                    ],
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: enabled && !state.streaming
                            ? () => _run(context)
                            : null,
                        icon: state.streaming
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          state.streaming
                              ? context.tr('analysis_running')
                              : '${context.tr('run_deep_analysis')} · 1 ⚡',
                        ),
                      ),
                    ),
                    // Once a report exists, reopening it must not re-run the
                    // analysis — that would charge a second credit for
                    // something the user already paid for.
                    if (state.report.isNotEmpty && !state.streaming) ...[
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: context.tr('view_report'),
                        icon: const Icon(Icons.article_outlined),
                        onPressed: () => DeepAnalysisSheet.show(
                          context,
                          context.read<DeepAnalysisCubit>(),
                          onRerun: () => _run(context),
                        ),
                      ),
                    ],
                  ],
                ),
                if (!enabled) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.tr('deep_analysis_no_data'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContextHint extends StatelessWidget {
  const _ContextHint({required this.onEdit});
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 18,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.tr('farm_context_empty'),
                style: theme.textTheme.bodySmall,
              ),
            ),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
