import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/widgets/image_pick_sheet.dart';
import '../../core/widgets/picked_image.dart';
import '../ai_models/data/model_repository.dart';
import '../auth/bloc/auth_cubit.dart';
import '../dashboard/bloc/history_cubit.dart' show LoadState;
import '../deep_analysis/data/analysis_context.dart';
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

  final Map<String, String?> _errors = {};
  AnalysisContext _farmContext = const AnalysisContext();

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
  void initState() {
    super.initState();
    _loadFarmContext();
  }

  Future<void> _loadFarmContext() async {
    final ctx = await AnalysisContextStore().read();
    if (!mounted) return;
    setState(() {
      _farmContext = ctx;
      if (_soilType.text.isEmpty && ctx.soilType.isNotEmpty) {
        _soilType.text = ctx.soilType;
      }
    });
  }

  Future<void> _editFarmContext(BuildContext context) async {
    final soilCtl = TextEditingController(text: _farmContext.soilType);
    final cropCtl = TextEditingController(text: _farmContext.cropType);
    final locCtl = TextEditingController(text: _farmContext.location);
    final irriCtl = TextEditingController(text: _farmContext.irrigationType);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (bctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(bctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Edit Farm Context', style: Theme.of(bctx).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: soilCtl,
              decoration: const InputDecoration(labelText: 'Soil Type', prefixIcon: Icon(Icons.terrain)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: cropCtl,
              decoration: const InputDecoration(labelText: 'Crop Type', prefixIcon: Icon(Icons.grass)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: locCtl,
              decoration: const InputDecoration(labelText: 'Location / Region', prefixIcon: Icon(Icons.place)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: irriCtl,
              decoration: const InputDecoration(labelText: 'Irrigation Type', prefixIcon: Icon(Icons.water_drop)),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final updated = _farmContext.copyWith(
                  soilType: soilCtl.text.trim(),
                  cropType: cropCtl.text.trim(),
                  location: locCtl.text.trim(),
                  irrigationType: irriCtl.text.trim(),
                );
                await AnalysisContextStore().write(updated);
                Navigator.of(bctx).pop();
                _loadFarmContext();
              },
              child: const Text('Save Context'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncIoTData() async {
    final api = context.read<ApiClient>();
    try {
      final devices = await api.get('/my-devices', query: api.authQuery());
      if (devices is List && devices.isNotEmpty) {
        final devId = devices.first['id'];
        final hist = await api.get('/iot-history/$devId', query: {'limit': 1});
        if (hist is Map && hist['status'] == 'success' && hist['data'] is List && (hist['data'] as List).isNotEmpty) {
          final reading = (hist['data'] as List).first as Map;
          setState(() {
            _ctl['n']!.text = (reading['nitrogen'] ?? 50).toString();
            _ctl['p']!.text = (reading['phosphorus'] ?? 40).toString();
            _ctl['k']!.text = (reading['potassium'] ?? 45).toString();
            _ctl['temperature']!.text = (reading['temperature'] ?? 28).toString();
            _ctl['humidity']!.text = (reading['humidity'] ?? 60).toString();
            _ctl['ph']!.text = (reading['ph'] ?? 6.5).toString();
            _errors.clear();
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('IoT telemetry synced successfully!')),
            );
          }
          return;
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No live IoT sensor data found for bound devices.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('IoT Sync: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _soilType.dispose();
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  (double min, double max, String label) _getFieldBounds(String key) {
    switch (key) {
      case 'n':
      case 'p':
      case 'k':
        return (0.0, 500.0, '0 to 500 mg/kg');
      case 'temperature':
        return (-50.0, 60.0, '-50 to 60 °C');
      case 'humidity':
        return (0.0, 100.0, '0 to 100%');
      case 'ph':
        return (0.0, 14.0, '0 to 14');
      case 'rainfall':
        return (0.0, 3000.0, '0 to 3000 mm');
      default:
        return (0.0, 10000.0, 'valid number');
    }
  }

  void _validateField(String key, String text) {
    final raw = text.trim();
    if (raw.isEmpty) {
      setState(() => _errors[key] = 'Required field');
      return;
    }
    final val = double.tryParse(raw);
    if (val == null) {
      setState(() => _errors[key] = 'Enter a valid number');
      return;
    }
    final (min, max, label) = _getFieldBounds(key);
    if (val < min || val > max) {
      setState(() => _errors[key] = 'Range: $label');
      return;
    }
    setState(() => _errors.remove(key));
  }

  bool _validateAll() {
    for (final e in _ctl.entries) {
      _validateField(e.key, e.value.text);
    }
    return _errors.isEmpty;
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
    if (!_validateAll()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Please correct invalid field values.')));
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
      listenWhen: (a, b) => a.soil != b.soil || a.error != b.error,
      listener: (ctx, state) {
        if (state.soil != null) _soilType.text = state.soil!.soilType;
        if (state.error != null) {
          ScaffoldMessenger.of(ctx)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      child: BlocBuilder<CropAdvisorCubit, CropAdvisorState>(
        builder: (context, state) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, size: 20),
                          const SizedBox(width: 8),
                          Text('Farm Context', style: Theme.of(context).textTheme.titleSmall),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _editFarmContext(context),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Edit Context'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.terrain, size: 14),
                            label: Text('Soil: ${_farmContext.soilType.isNotEmpty ? _farmContext.soilType : "Unspecified"}'),
                          ),
                          Chip(
                            avatar: const Icon(Icons.grass, size: 14),
                            label: Text('Crop: ${_farmContext.cropType.isNotEmpty ? _farmContext.cropType : "Unspecified"}'),
                          ),
                          if (_farmContext.location.isNotEmpty)
                            Chip(
                              avatar: const Icon(Icons.place, size: 14),
                              label: Text('Loc: ${_farmContext.location}'),
                            ),
                          if (_farmContext.irrigationType.isNotEmpty)
                            Chip(
                              avatar: const Icon(Icons.water_drop, size: 14),
                              label: Text('Irri: ${_farmContext.irrigationType}'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('2 · Environment', style: Theme.of(context).textTheme.titleMedium),
                  OutlinedButton.icon(
                    onPressed: _syncIoTData,
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Auto-fill IoT Data'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ctl.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final e = _ctl.entries.elementAt(i);
                  return TextField(
                    controller: e.value,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (v) => _validateField(e.key, v),
                    decoration: InputDecoration(
                      labelText: _labels[e.key],
                      errorText: _errors[e.key],
                    ),
                  );
                },
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
