import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localizations.dart';
import '../bloc/deep_analysis_cubit.dart';
import '../data/analysis_context.dart';

/// Editor for the farm context sent with a deep analysis.
///
/// The web keeps this as a bar permanently above the dashboard; on a phone
/// there is no room for eight fields that change once a season, so it lives
/// behind a sheet and shows a summary on the card instead.
class FarmContextSheet extends StatefulWidget {
  const FarmContextSheet({super.key, required this.cubit});

  final DeepAnalysisCubit cubit;

  static Future<void> show(BuildContext context, DeepAnalysisCubit cubit) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FarmContextSheet(cubit: cubit),
    );
  }

  @override
  State<FarmContextSheet> createState() => _FarmContextSheetState();
}

class _FarmContextSheetState extends State<FarmContextSheet> {
  late AnalysisContext _ctx = widget.cubit.state.context;
  late final TextEditingController _variety = TextEditingController(
    text: _ctx.cropVariety,
  );
  late final TextEditingController _location = TextEditingController(
    text: _ctx.location,
  );
  late final TextEditingController _water = TextEditingController(
    text: _ctx.waterQuantity,
  );

  @override
  void dispose() {
    _variety.dispose();
    _location.dispose();
    _water.dispose();
    super.dispose();
  }

  void _setIrrigation(String? value) {
    final v = value ?? '';
    setState(() {
      _ctx = _ctx.copyWith(irrigationType: v);
      // Prefill the typical consumption for the method, as the web does — the
      // user can still overwrite it.
      final baseline = FarmContextOptions.waterBaselines[v];
      if (baseline != null) {
        final text = baseline.toStringAsFixed(0);
        _ctx = _ctx.copyWith(waterQuantity: text);
        _water.text = text;
      }
    });
  }

  void _save() {
    final ctx = _ctx.copyWith(
      cropVariety: _variety.text.trim(),
      location: _location.text.trim(),
      waterQuantity: _water.text.trim(),
    );
    widget.cubit.updateContext(ctx);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('farm_context'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr('farm_context_hint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 16),
            _OptionField(
              label: context.tr('ctx_crop_type'),
              icon: Icons.grass_outlined,
              value: _ctx.cropType,
              options: FarmContextOptions.crops,
              onChanged: (v) =>
                  setState(() => _ctx = _ctx.copyWith(cropType: v ?? '')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _variety,
              decoration: InputDecoration(
                labelText: context.tr('ctx_crop_variety'),
                prefixIcon: const Icon(Icons.spa_outlined),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration: InputDecoration(
                labelText: context.tr('ctx_location'),
                prefixIcon: const Icon(Icons.place_outlined),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            _OptionField(
              label: context.tr('ctx_season'),
              icon: Icons.calendar_today_outlined,
              value: _ctx.season,
              options: FarmContextOptions.seasons,
              onChanged: (v) =>
                  setState(() => _ctx = _ctx.copyWith(season: v ?? '')),
            ),
            const SizedBox(height: 12),
            _OptionField(
              label: context.tr('ctx_soil_type'),
              icon: Icons.terrain_outlined,
              value: _ctx.soilType,
              options: FarmContextOptions.soilTypes,
              onChanged: (v) =>
                  setState(() => _ctx = _ctx.copyWith(soilType: v ?? '')),
            ),
            const SizedBox(height: 12),
            _OptionField(
              label: context.tr('ctx_irrigation_type'),
              icon: Icons.water_drop_outlined,
              value: _ctx.irrigationType,
              options: FarmContextOptions.irrigationTypes,
              onChanged: _setIrrigation,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _water,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: context.tr('ctx_water_quantity'),
                suffixText: context.tr('ctx_water_unit'),
                prefixIcon: const Icon(Icons.opacity_outlined),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            _OptionField(
              label: context.tr('ctx_analysis_depth'),
              icon: Icons.tune,
              value: _ctx.analysisDepth,
              options: FarmContextOptions.analysisDepths,
              onChanged: (v) =>
                  setState(() => _ctx = _ctx.copyWith(analysisDepth: v ?? '')),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.tr('cancel')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    child: Text(context.tr('save')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

/// A dropdown over option keys, labelled from the translations and clearable.
///
/// Clearing matters: an unset field is not the same as a wrong one — the
/// backend fills blanks with a stated default and tells the user it did.
class _OptionField extends StatelessWidget {
  const _OptionField({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value.isEmpty ? null : value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        isDense: true,
        suffixIcon: value.isEmpty
            ? null
            : IconButton(
                tooltip: context.tr('clear'),
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () => onChanged(''),
              ),
      ),
      items: [
        for (final o in options)
          DropdownMenuItem(value: o, child: Text(context.tr('ctx_$o'))),
      ],
      onChanged: onChanged,
    );
  }
}
