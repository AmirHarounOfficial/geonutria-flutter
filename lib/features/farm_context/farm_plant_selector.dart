import 'package:geonutria_mobile/core/localization/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'farm_hierarchy_cubit.dart';

/// 3-tier cascaded Farm / Crop / Tree context selector mirroring the web
/// dashboard's `FarmPlantSelector.jsx`.
class FarmPlantSelector extends StatelessWidget {
  const FarmPlantSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FarmHierarchyCubit, FarmHierarchyState>(
      builder: (context, state) {
        if (state.farms.isEmpty && !state.isLoading) {
          return SizedBox.shrink();
        }

        final cubit = context.read<FarmHierarchyCubit>();

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.agriculture_outlined, size: 18),
                  SizedBox(width: 6),
                  Text(
                    context.ui('Farm Context'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (state.isLoading) ...[
                    SizedBox(width: 8),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // 1. Farm Selector
                    Builder(
                      builder: (context) {
                        final uniqueFarms = <int, FarmItem>{};
                        for (final f in state.farms) {
                          uniqueFarms[f.id] = f;
                        }
                        final farmList = uniqueFarms.values.toList();
                        final int? selectedFarmValue =
                            (state.selectedFarmId != null &&
                                uniqueFarms.containsKey(state.selectedFarmId))
                            ? state.selectedFarmId
                            : null;

                        return SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<int?>(
                            isExpanded: true,
                            value: selectedFarmValue,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              prefixIcon: Icon(Icons.location_on, size: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              hintText: context.ui('Select Farm'),
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(
                                  context.ui('-- Select Farm --'),
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              for (final f in farmList)
                                DropdownMenuItem<int?>(
                                  value: f.id,
                                  child: Text(
                                    f.name,
                                    style: TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (val) => cubit.selectFarm(val),
                          ),
                        );
                      },
                    ),
                    SizedBox(width: 8),

                    // 2. Crop Selector
                    Builder(
                      builder: (context) {
                        final uniqueCrops = <int, CropItem>{};
                        for (final c in state.filteredCrops) {
                          uniqueCrops[c.id] = c;
                        }
                        final cropList = uniqueCrops.values.toList();
                        final int? selectedCropValue =
                            (state.selectedCropId != null &&
                                uniqueCrops.containsKey(state.selectedCropId))
                            ? state.selectedCropId
                            : null;

                        return SizedBox(
                          width: 150,
                          child: DropdownButtonFormField<int?>(
                            isExpanded: true,
                            value: selectedCropValue,
                            decoration: InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              prefixIcon: Icon(
                                Icons.grass,
                                size: 16,
                                color: state.selectedFarmId != null
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              hintText: context.ui('Select Crop'),
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(
                                  context.ui('-- Select Crop --'),
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              for (final c in cropList)
                                DropdownMenuItem<int?>(
                                  value: c.id,
                                  child: Text(
                                    c.name,
                                    style: TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: state.selectedFarmId == null
                                ? null
                                : (val) => cubit.selectCrop(val),
                          ),
                        );
                      },
                    ),

                    // 3. Tree Selector (Only if selected crop is a tree)
                    if (state.isTreeCrop) ...[
                      SizedBox(width: 8),
                      Builder(
                        builder: (context) {
                          final uniqueTrees = <int, TreeItem>{};
                          for (final t in state.filteredTrees) {
                            uniqueTrees[t.id] = t;
                          }
                          final treeList = uniqueTrees.values.toList();
                          final int? selectedTreeValue =
                              (state.selectedTreeId != null &&
                                  uniqueTrees.containsKey(state.selectedTreeId))
                              ? state.selectedTreeId
                              : null;

                          return SizedBox(
                            width: 160,
                            child: DropdownButtonFormField<int?>(
                              isExpanded: true,
                              value: selectedTreeValue,
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                prefixIcon: Icon(
                                  Icons.park,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                hintText: context.ui('Select Tree'),
                              ),
                              items: [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text(
                                    context.ui('-- Select Tree --'),
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                                for (final t in treeList)
                                  DropdownMenuItem<int?>(
                                    value: t.id,
                                    child: Text(
                                      '${t.treeName} (${t.treeCode})',
                                      style: TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                              ],
                              onChanged: state.selectedCropId == null
                                  ? null
                                  : (val) => cubit.selectTree(val),
                            ),
                          );
                        },
                      ),
                    ],
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
