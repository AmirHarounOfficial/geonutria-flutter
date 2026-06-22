import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_client.dart';
import '../ai_models/data/model_repository.dart';
import '../auth/bloc/auth_cubit.dart';
import '../dashboard/bloc/history_cubit.dart' show LoadState;
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
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _i(String k) => int.tryParse(_ctl[k]!.text) ?? 0;
  double _d(String k) => double.tryParse(_ctl[k]!.text) ?? 0;

  void _predict() {
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
            DropdownButtonFormField<String>(
              initialValue: _crop,
              decoration: const InputDecoration(labelText: 'Crop'),
              items: [
                for (final c in _crops)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _crop = v ?? 'Rice'),
            ),
            const SizedBox(height: 12),
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
