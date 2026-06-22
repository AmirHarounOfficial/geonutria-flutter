import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/map_location_picker.dart';
import '../../../core/widgets/status_views.dart';
import '../../dashboard/bloc/history_cubit.dart' show LoadState;
import '../bloc/assets_cubit.dart';
import '../data/assets_repository.dart';

/// Farm → crop → tree management, with inline expansion.
class AssetsTab extends StatelessWidget {
  const AssetsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AssetsCubit, AssetsState>(
      builder: (context, state) {
        return Scaffold(
          body: switch (state.state) {
            LoadState.loading => const LoadingView(),
            LoadState.error => ErrorView(
                message: state.error ?? context.tr('error_generic'),
                onRetry: () => context.read<AssetsCubit>().loadFarms(),
              ),
            _ => state.farms.isEmpty
                ? const EmptyView(
                    message: 'No farms yet. Add your first farm.',
                    icon: Icons.agriculture_outlined)
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [for (final f in state.farms) _FarmTile(farm: f)],
                  ),
          },
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddFarm(context),
            icon: const Icon(Icons.add),
            label: const Text('Add farm'),
          ),
        );
      },
    );
  }

  void _showAddFarm(BuildContext context) {
    final name = TextEditingController();
    final address = TextEditingController();
    final area = TextEditingController();
    double? lat;
    double? lon;
    final cubit = context.read<AssetsCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(sctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (bctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('New farm', style: Theme.of(bctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Farm name')),
              const SizedBox(height: 8),
              TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 8),
              TextField(
                controller: area,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total area (Ha)'),
              ),
              const SizedBox(height: 8),
              MapLocationPicker(
                label: 'Location',
                latitude: lat,
                longitude: lon,
                onChanged: (la, lo) => setSheet(() {
                  lat = la;
                  lon = lo;
                }),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  cubit.createFarm(
                    name: name.text.trim(),
                    address: address.text.trim(),
                    area: double.tryParse(area.text) ?? 0,
                    lat: lat,
                    lon: lon,
                  );
                  Navigator.of(sctx).pop();
                },
                child: Text(bctx.tr('save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FarmTile extends StatelessWidget {
  const _FarmTile({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AssetsCubit>().repo;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.agriculture),
        title: Text(farm.name.isEmpty ? 'Farm ${farm.id}' : farm.name),
        subtitle: Text([
          if (farm.address != null && farm.address!.isNotEmpty) farm.address,
          if (farm.totalArea != null) '${farm.totalArea} Ha',
        ].whereType<String>().join(' · ')),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => context.read<AssetsCubit>().deleteFarm(farm.id),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          FutureBuilder<List<Crop>>(
            future: repo.getCrops(farm.id),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                );
              }
              final crops = snap.data ?? [];
              if (crops.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('No crops recorded.'),
                );
              }
              return Column(
                children: [for (final c in crops) _CropTile(crop: c)],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CropTile extends StatelessWidget {
  const _CropTile({required this.crop});
  final Crop crop;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AssetsCubit>().repo;
    return ExpansionTile(
      tilePadding: const EdgeInsetsDirectional.only(start: 8),
      leading: const Icon(Icons.grass, size: 20),
      title: Text(crop.name),
      subtitle: Text([
        if (crop.category != null) crop.category,
        if (crop.plantedArea != null) '${crop.plantedArea} Ha',
        if (crop.healthStatus != null) crop.healthStatus,
      ].whereType<String>().join(' · ')),
      children: [
        FutureBuilder<List<Tree>>(
          future: repo.getTrees(crop.id),
          builder: (ctx, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              );
            }
            final trees = snap.data ?? [];
            if (trees.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(8),
                child: Text('No trees recorded.'),
              );
            }
            return Column(
              children: [
                for (final t in trees)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.park, size: 18),
                    title: Text(t.name),
                    subtitle: Text(t.code ?? ''),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
