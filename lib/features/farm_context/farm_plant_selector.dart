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
          return const SizedBox.shrink();
        }

        final cubit = context.read<FarmHierarchyCubit>();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.agriculture_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Farm Context',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (state.isLoading) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // 1. Farm Selector
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: state.selectedFarmId,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          prefixIcon: const Icon(Icons.location_on, size: 16),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          hintText: 'Select Farm',
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('-- Select Farm --', style: TextStyle(fontSize: 12)),
                          ),
                          for (final f in state.farms)
                            DropdownMenuItem<int>(
                              value: f.id,
                              child: Text(f.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (val) => cubit.selectFarm(val),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 2. Crop Selector
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        initialValue: state.selectedCropId,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          prefixIcon: Icon(
                            Icons.grass,
                            size: 16,
                            color: state.selectedFarmId != null ? Colors.green : Colors.grey,
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          hintText: 'Select Crop',
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('-- Select Crop --', style: TextStyle(fontSize: 12)),
                          ),
                          for (final c in state.filteredCrops)
                            DropdownMenuItem<int>(
                              value: c.id,
                              child: Text(c.name, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: state.selectedFarmId == null ? null : (val) => cubit.selectCrop(val),
                      ),
                    ),

                    // 3. Tree Selector (Only if selected crop is a tree)
                    if (state.isTreeCrop) ...[
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 160,
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          initialValue: state.selectedTreeId,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            prefixIcon: const Icon(Icons.park, size: 16, color: Colors.green),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            hintText: 'Select Tree',
                          ),
                          items: [
                            const DropdownMenuItem<int>(
                              value: null,
                              child: Text('-- Select Tree --', style: TextStyle(fontSize: 12)),
                            ),
                            for (final t in state.filteredTrees)
                              DropdownMenuItem<int>(
                                value: t.id,
                                child: Text('${t.treeName} (${t.treeCode})', style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              ),
                          ],
                          onChanged: state.selectedCropId == null ? null : (val) => cubit.selectTree(val),
                        ),
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
