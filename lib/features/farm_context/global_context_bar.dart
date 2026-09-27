import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/app_localizations.dart';
import '../deep_analysis/data/analysis_context.dart';
import 'farm_hierarchy_cubit.dart';

/// Reusable Global Farm Context Bar matching the web dashboard's `GlobalContextBar.js`.
///
/// Features:
/// - 1. Farm Selector (Dropdown Select from user hierarchy)
/// - 2. Crop Type Selector (Dropdown Select filtered by selected Farm or Custom manual entry)
/// - 3. Geographic Location (Dropdown Select)
/// - 4. Current Season
/// - 5. Irrigation Type
/// - 6. Water Quantity (m³/Feddan/Week)
/// - 7. Soil Type
/// - 8. Analysis Response Depth
class GlobalContextBar extends StatefulWidget {
  const GlobalContextBar({super.key, this.onContextChanged});

  final ValueChanged<AnalysisContext>? onContextChanged;

  @override
  State<GlobalContextBar> createState() => _GlobalContextBarState();
}

class _GlobalContextBarState extends State<GlobalContextBar> {
  bool _isExpanded = false;
  AnalysisContext _context = const AnalysisContext();
  final _store = AnalysisContextStore();

  bool _isCustomCrop = false;
  final _customCropCtl = TextEditingController();

  final _locationCtl = TextEditingController();
  final _seasonCtl = TextEditingController();
  final _irrigationTypeCtl = TextEditingController();
  final _waterQuantityCtl = TextEditingController();
  final _soilTypeCtl = TextEditingController();
  final _analysisDepthCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContext();
    AnalysisContextStore.changes.addListener(_loadContext);
  }

  Future<void> _loadContext() async {
    final loaded = await _store.read();
    if (!mounted) return;
    final isCustom =
        loaded.cropType.isNotEmpty &&
        !FarmContextOptions.crops.contains(loaded.cropType);
    setState(() {
      _context = loaded;
      if (_locationCtl.text != loaded.location) {
        _locationCtl.text = loaded.location;
      }
      _seasonCtl.text = loaded.season;
      _irrigationTypeCtl.text = loaded.irrigationType;
      _waterQuantityCtl.text = loaded.waterQuantity;
      _soilTypeCtl.text = loaded.soilType;
      _analysisDepthCtl.text = loaded.analysisDepth;
      _customCropCtl.text = loaded.cropType;
      _isCustomCrop = isCustom;
    });
  }

  void _updateContext(AnalysisContext next) {
    setState(() => _context = next);
    _store.write(next);
    widget.onContextChanged?.call(next);
  }

  void _onIrrigationChanged(String? val) {
    val ??= '';
    final baseline = FarmContextOptions.waterBaselines[val];
    final nextWater = baseline != null ? '$baseline' : _waterQuantityCtl.text;
    _waterQuantityCtl.text = nextWater;
    _irrigationTypeCtl.text = val;

    _updateContext(
      _context.copyWith(irrigationType: val, waterQuantity: nextWater),
    );
  }

  @override
  void dispose() {
    AnalysisContextStore.changes.removeListener(_loadContext);
    _customCropCtl.dispose();
    _locationCtl.dispose();
    _seasonCtl.dispose();
    _irrigationTypeCtl.dispose();
    _waterQuantityCtl.dispose();
    _soilTypeCtl.dispose();
    _analysisDepthCtl.dispose();
    super.dispose();
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
    bool disabled = false,
    Widget? headerTrailing,
    String Function(String)? labelBuilder,
  }) {
    final cleanOptions = options.where((o) => o.isNotEmpty).toSet().toList();
    if (value.isNotEmpty && !cleanOptions.contains(value)) {
      cleanOptions.add(value);
    }

    final selectedValue = (value.isEmpty || !cleanOptions.contains(value))
        ? null
        : value;

    String resolveLabel(String opt) {
      if (labelBuilder != null) return labelBuilder(opt);
      if (opt.isEmpty) return '';
      final key = 'ctx_$opt';
      final tr = context.tr(key);
      if (tr != key) return tr;
      return opt[0].toUpperCase() + opt.substring(1);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (headerTrailing != null)
              Flexible(
                child: FittedBox(fit: BoxFit.scaleDown, child: headerTrailing),
              ),
          ],
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          isExpanded: true,
          value: selectedValue,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          hint: Text(
            context.tr('fc_select_placeholder'),
            style: const TextStyle(fontSize: 12),
          ),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(
                context.tr('fc_select_placeholder'),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            for (final opt in cleanOptions)
              DropdownMenuItem<String>(
                value: opt,
                child: Text(
                  resolveLabel(opt),
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: disabled ? null : onChanged,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required IconData icon,
    required TextEditingController controller,
    required String hint,
    String? suffix,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12),
            suffixText: suffix,
            suffixStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filledCount = _context.filledCount;

    return BlocBuilder<FarmHierarchyCubit, FarmHierarchyState>(
      builder: (context, hierarchyState) {
        final hierarchyCubit = context.read<FarmHierarchyCubit>();

        final selectedFarmObj = hierarchyState.selectedFarmId != null
            ? hierarchyState.farms.firstWhere(
                (f) => f.id == hierarchyState.selectedFarmId,
                orElse: () => const FarmItem(id: -1, name: ''),
              )
            : null;

        // Base crop list
        final baseCropOptions = hierarchyState.selectedFarmId != null
            ? hierarchyState.filteredCrops.map((c) => c.name).toList()
            : FarmContextOptions.crops;

        final cropDropdownOptions = [...baseCropOptions, '__custom__'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header button
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.layers,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.tr('fc_title'),
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (filledCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$filledCount/8',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _isExpanded
                              ? context.tr('fc_collapse')
                              : context.tr('fc_expand'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ],
                  ),
                ),
              ),

              // Expandable Grid
              if (_isExpanded)
                Padding(
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    bottom: 14,
                    top: 4,
                  ),
                  child: Column(
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.2,
                        children: [
                          // 1. Select Farm (Dropdown from user hierarchy)
                          _buildDropdownField(
                            label: context.tr('fc_select_farm'),
                            icon: Icons.agriculture,
                            value:
                                selectedFarmObj != null &&
                                    selectedFarmObj.id != -1
                                ? selectedFarmObj.name
                                : '',
                            options: hierarchyState.farms
                                .map((f) => f.name)
                                .toList(),
                            onChanged: (v) {
                              if (v == null || v.isEmpty) {
                                hierarchyCubit.selectFarm(null);
                              } else {
                                final found = hierarchyState.farms.firstWhere(
                                  (f) => f.name == v,
                                  orElse: () => FarmItem(id: -1, name: v),
                                );
                                if (found.id != -1) {
                                  hierarchyCubit.selectFarm(found.id);
                                }
                              }
                            },
                          ),

                          // 2. Select Crop (Dependent on selected farm or custom entry)
                          if (_isCustomCrop)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.grass,
                                      size: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        context
                                            .tr('fc_crop_type')
                                            .toUpperCase(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () =>
                                          setState(() => _isCustomCrop = false),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.list,
                                              size: 12,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              context.tr('fc_choose_from_list'),
                                              style: TextStyle(
                                                fontSize: 9,
                                                color: Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _customCropCtl,
                                  style: const TextStyle(fontSize: 12),
                                  onChanged: (v) {
                                    _updateContext(
                                      _context.copyWith(cropType: v.trim()),
                                    );
                                  },
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: context.tr('fc_custom_crop_hint'),
                                    hintStyle: const TextStyle(fontSize: 11),
                                    suffixIcon: IconButton(
                                      icon: const Icon(Icons.list, size: 16),
                                      tooltip: context.tr(
                                        'fc_choose_from_list',
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () =>
                                          setState(() => _isCustomCrop = false),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          else
                            _buildDropdownField(
                              label: context.tr('fc_crop_type'),
                              icon: Icons.grass,
                              headerTrailing: InkWell(
                                onTap: () =>
                                    setState(() => _isCustomCrop = true),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 2,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit_note,
                                        size: 12,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                      const SizedBox(width: 2),
                                      Text(
                                        context.tr('fc_custom_crop'),
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              value: hierarchyState.selectedCropId != null
                                  ? (hierarchyState.selectedCropObj?.name ??
                                        _context.cropType)
                                  : _context.cropType,
                              options: cropDropdownOptions,
                              labelBuilder: (c) {
                                if (c == '__custom__') {
                                  return '✍️ ${context.tr('fc_custom_crop')}';
                                }
                                final key = 'ctx_$c';
                                final tr = context.tr(key);
                                return tr != key ? tr : c;
                              },
                              disabled:
                                  hierarchyState.farms.isNotEmpty &&
                                  hierarchyState.selectedFarmId == null,
                              onChanged: (v) {
                                if (v == '__custom__') {
                                  setState(() {
                                    _isCustomCrop = true;
                                  });
                                  return;
                                }
                                if (v == null || v.isEmpty) {
                                  hierarchyCubit.selectCrop(null);
                                  _customCropCtl.text = '';
                                  _updateContext(
                                    _context.copyWith(cropType: ''),
                                  );
                                } else {
                                  final found = hierarchyState.crops.firstWhere(
                                    (c) => c.name == v,
                                    orElse: () =>
                                        CropItem(id: -1, farmId: -1, name: v),
                                  );
                                  if (found.id != -1) {
                                    hierarchyCubit.selectCrop(found.id);
                                  }
                                  _customCropCtl.text = v;
                                  _updateContext(
                                    _context.copyWith(cropType: v),
                                  );
                                }
                              },
                            ),

                          // 3. Geographic Location (Dropdown Select)
                          _buildDropdownField(
                            label: context.tr('fc_location'),
                            icon: Icons.location_on,
                            value: _context.location,
                            options: FarmContextOptions.locations,
                            onChanged: (v) => _updateContext(
                              _context.copyWith(location: v ?? ''),
                            ),
                          ),

                          // 4. Current Season
                          _buildDropdownField(
                            label: context.tr('fc_season'),
                            icon: Icons.wb_sunny,
                            value: _context.season,
                            options: FarmContextOptions.seasons,
                            onChanged: (v) => _updateContext(
                              _context.copyWith(season: v ?? ''),
                            ),
                          ),

                          // 5. Irrigation Type
                          _buildDropdownField(
                            label: context.tr('fc_irrigation_type'),
                            icon: Icons.water_drop,
                            value: _context.irrigationType,
                            options: FarmContextOptions.irrigationTypes,
                            onChanged: _onIrrigationChanged,
                          ),

                          // 6. Water Quantity (numeric input)
                          _buildTextField(
                            label: context.tr('fc_water_quantity'),
                            icon: Icons.opacity,
                            controller: _waterQuantityCtl,
                            hint: '0',
                            suffix: context.tr('fc_water_unit'),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (v) => _updateContext(
                              _context.copyWith(waterQuantity: v.trim()),
                            ),
                          ),

                          // 7. Soil Type
                          _buildDropdownField(
                            label: context.tr('fc_soil_type'),
                            icon: Icons.terrain,
                            value: _context.soilType,
                            options: FarmContextOptions.soilTypes,
                            onChanged: (v) => _updateContext(
                              _context.copyWith(soilType: v ?? ''),
                            ),
                          ),

                          // 8. Analysis Response Depth
                          _buildDropdownField(
                            label: context.tr('fc_analysis_depth'),
                            icon: Icons.tune,
                            value: _context.analysisDepth,
                            options: FarmContextOptions.analysisDepths,
                            onChanged: (v) => _updateContext(
                              _context.copyWith(analysisDepth: v ?? ''),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
