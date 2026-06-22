import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/image_pick_sheet.dart';
import '../../core/widgets/picked_image.dart';
import '../ai_models/data/model_repository.dart';
import '../auth/bloc/auth_cubit.dart';
import '../dashboard/bloc/history_cubit.dart' show LoadState;
import 'crop_advisor_cubit.dart';

/// Crop Advisor: classify soil from a photo, then recommend the top crops for
/// the soil + environment.
class CropAdvisorScreen extends StatelessWidget {
  const CropAdvisorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => CropAdvisorCubit(
        ModelRepository(ctx.read<ApiClient>()),
        ctx.read<AuthCubit>(),
      ),
      child: const _CropView(),
    );
  }
}

class _CropView extends StatefulWidget {
  const _CropView();
  @override
  State<_CropView> createState() => _CropViewState();
}

class _CropViewState extends State<_CropView> {
  XFile? _soilFile;
  final _soilType = TextEditingController();
  final _ctl = {
    'n': TextEditingController(text: '50'),
    'p': TextEditingController(text: '40'),
    'k': TextEditingController(text: '45'),
    'temperature': TextEditingController(text: '28'),
    'humidity': TextEditingController(text: '60'),
    'ph': TextEditingController(text: '6.5'),
    'rainfall': TextEditingController(text: '100'),
  };

  static const _labels = {
    'n': 'Nitrogen (N)',
    'p': 'Phosphorus (P)',
    'k': 'Potassium (K)',
    'temperature': 'Temperature (°C)',
    'humidity': 'Humidity (%)',
    'ph': 'Soil pH',
    'rainfall': 'Rainfall (mm)',
  };

  @override
  void dispose() {
    _soilType.dispose();
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _v(String k) => double.tryParse(_ctl[k]!.text) ?? 0;

  Future<void> _pickSoil() async {
    final picked = await pickImage(context);
    if (picked != null) {
      setState(() => _soilFile = picked);
      if (mounted) context.read<CropAdvisorCubit>().classifySoil(picked);
    }
  }

  void _recommend() {
    final soil = _soilType.text.trim();
    if (soil.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Set a soil type (classify a photo or type it).')));
      return;
    }
    context.read<CropAdvisorCubit>().recommend(
          n: _v('n'),
          p: _v('p'),
          k: _v('k'),
          temperature: _v('temperature'),
          humidity: _v('humidity'),
          ph: _v('ph'),
          rainfall: _v('rainfall'),
          soilType: soil,
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CropAdvisorCubit, CropAdvisorState>(
      listenWhen: (a, b) => a.soil != b.soil,
      listener: (ctx, state) {
        if (state.soil != null) _soilType.text = state.soil!.soilType;
      },
      child: BlocBuilder<CropAdvisorCubit, CropAdvisorState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('1 · Soil type',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickSoil,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _soilFile == null
                      ? const Center(
                          child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_a_photo_outlined, size: 36),
                            SizedBox(height: 8),
                            Text('Tap to classify a soil photo (5 ⚡)'),
                          ],
                        ))
                      : PickedImage(file: _soilFile!),
                ),
              ),
              if (state.soilState == LoadState.loading)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _soilType,
                decoration: InputDecoration(
                  labelText: 'Soil type',
                  suffixText: state.soil != null
                      ? '${state.soil!.confidence.toStringAsFixed(0)}%'
                      : null,
                ),
              ),
              const SizedBox(height: 20),
              Text('2 · Environment',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.6,
                children: [
                  for (final e in _ctl.entries)
                    TextField(
                      controller: e.value,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: _labels[e.key]),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: state.recState == LoadState.loading ? null : _recommend,
                icon: state.recState == LoadState.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.grass),
                label: Text('Recommend crops  ·  5 ⚡'),
              ),
              if (state.crops.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Top crops',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final c in state.crops) _CropTile(rec: c),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CropTile extends StatelessWidget {
  const _CropTile({required this.rec});
  final CropRec rec;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.eco, color: Colors.green),
        title: Text(rec.crop),
        trailing: Text('${rec.confidence.toStringAsFixed(1)}%',
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
