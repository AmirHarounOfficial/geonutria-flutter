import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_client.dart';
import '../ai_models/data/model_repository.dart';
import '../auth/bloc/auth_cubit.dart';
import '../dashboard/bloc/history_cubit.dart' show LoadState;
import '../deep_analysis/data/analysis_context.dart';
import 'yield_cubit.dart';

/// Predicts crop yield (kg/ha, also shown as kg/acre) from environment inputs.
class YieldScreen extends StatelessWidget {
  const YieldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => YieldCubit(
        ModelRepository(ctx.read<ApiClient>()),
        ctx.read<AuthCubit>(),
      ),
      child: const _YieldView(),
    );
  }
}

class _YieldView extends StatefulWidget {
  const _YieldView();
  @override
  State<_YieldView> createState() => _YieldViewState();
}

class _YieldViewState extends State<_YieldView> {
  static const _crops = ['Rice', 'Maize', 'Chickpea', 'Cotton'];
  String _crop = 'Rice';

  final _ctl = {
    'n': TextEditingController(text: '80'),
    'p': TextEditingController(text: '40'),
    'k': TextEditingController(text: '40'),
    'temperature': TextEditingController(text: '28'),
    'humidity': TextEditingController(text: '60'),
    'ph': TextEditingController(text: '6.5'),
    'rainfall': TextEditingController(text: '200'),
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
      if (ctx.cropType.isNotEmpty) {
        final match = _crops.firstWhere(
          (c) => c.toLowerCase() == ctx.cropType.toLowerCase(),
          orElse: () => _crop,
        );
        _crop = match;
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
              controller: cropCtl,
              decoration: const InputDecoration(labelText: 'Crop Type', prefixIcon: Icon(Icons.grass)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: soilCtl,
              decoration: const InputDecoration(labelText: 'Soil Type', prefixIcon: Icon(Icons.terrain)),
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
                  cropType: cropCtl.text.trim(),
                  soilType: soilCtl.text.trim(),
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
            _ctl['n']!.text = (reading['nitrogen'] ?? 80).toString();
            _ctl['p']!.text = (reading['phosphorus'] ?? 40).toString();
            _ctl['k']!.text = (reading['potassium'] ?? 40).toString();
            _ctl['temperature']!.text = (reading['temperature'] ?? 28).toString();
            _ctl['humidity']!.text = (reading['humidity'] ?? 60).toString();
            _ctl['ph']!.text = (reading['ph'] ?? 6.5).toString();
            _errors.clear();
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('IoT sensor telemetry synced successfully!')),
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

  int _i(String k) => int.tryParse(_ctl[k]!.text) ?? 0;
  double _d(String k) => double.tryParse(_ctl[k]!.text) ?? 0;

  void _predict() {
    if (!_validateAll()) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Please correct invalid input values.')));
      return;
    }
    context.read<YieldCubit>().predict(
          crop: _crop,
          n: _i('n'),
          p: _i('p'),
          k: _i('k'),
          temperature: _i('temperature'),
          humidity: _i('humidity'),
          ph: _d('ph'),
          rainfall: _i('rainfall'),
        );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<YieldCubit, YieldState>(
      builder: (context, state) {
        final busy = state.state == LoadState.loading;
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
                          avatar: const Icon(Icons.grass, size: 14),
                          label: Text('Crop: ${_farmContext.cropType.isNotEmpty ? _farmContext.cropType : "Unspecified"}'),
                        ),
                        Chip(
                          avatar: const Icon(Icons.terrain, size: 14),
                          label: Text('Soil: ${_farmContext.soilType.isNotEmpty ? _farmContext.soilType : "Unspecified"}'),
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
            DropdownButtonFormField<String>(
              initialValue: _crop,
              decoration: const InputDecoration(labelText: 'Crop Selection'),
              items: [
                for (final c in _crops)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _crop = v ?? 'Rice'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Soil & Environmental Telemetry', style: Theme.of(context).textTheme.titleMedium),
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
              onPressed: busy ? null : _predict,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.analytics),
              label: const Text('Predict yield  ·  5 ⚡'),
            ),
            if (state.state == LoadState.error && state.error != null) ...[
              const SizedBox(height: 16),
              Text(state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (state.kgPerHa != null) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.grass, size: 40, color: Colors.green),
                      const SizedBox(height: 8),
                      Text('${state.kgPerHa} kg/ha',
                          style: Theme.of(context).textTheme.headlineSmall),
                      Text(
                        '${state.kgPerAcre!.toStringAsFixed(0)} kg/acre',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
