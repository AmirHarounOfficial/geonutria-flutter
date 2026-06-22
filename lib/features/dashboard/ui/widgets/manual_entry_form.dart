import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../bloc/history_cubit.dart' show LoadState;
import '../../bloc/manual_diagnosis_cubit.dart';
import 'diagnosis_card.dart';

/// Lets the user enter sensor values by hand and run the AI health model
/// (mirrors the web "Manual entry" mode).
class ManualEntryForm extends StatefulWidget {
  const ManualEntryForm({super.key});

  @override
  State<ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<ManualEntryForm> {
  final _fields = <String, TextEditingController>{
    'moisture': TextEditingController(text: '40'),
    'soilTemp': TextEditingController(text: '25'),
    'ambientTemp': TextEditingController(text: '28'),
    'humidity': TextEditingController(text: '55'),
    'ph': TextEditingController(text: '6.5'),
    'nitrogen': TextEditingController(text: '50'),
    'phosphorus': TextEditingController(text: '40'),
    'potassium': TextEditingController(text: '45'),
    'ec': TextEditingController(text: '500'),
  };

  static const _labels = {
    'moisture': 'Soil Moisture (%)',
    'soilTemp': 'Soil Temp (°C)',
    'ambientTemp': 'Ambient Temp (°C)',
    'humidity': 'Humidity (%)',
    'ph': 'Soil pH',
    'nitrogen': 'Nitrogen (N)',
    'phosphorus': 'Phosphorus (P)',
    'potassium': 'Potassium (K)',
    'ec': 'EC (µS/cm)',
  };

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _v(String k) => double.tryParse(_fields[k]!.text) ?? 0;

  void _run() {
    context.read<ManualDiagnosisCubit>().run(
          moisture: _v('moisture'),
          soilTemp: _v('soilTemp'),
          ambientTemp: _v('ambientTemp'),
          humidity: _v('humidity'),
          ph: _v('ph'),
          nitrogen: _v('nitrogen'),
          phosphorus: _v('phosphorus'),
          potassium: _v('potassium'),
          ec: _v('ec'),
        );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          context.tr('manual_entry'),
          style: Theme.of(context).textTheme.titleMedium,
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
            for (final entry in _fields.entries)
              TextField(
                controller: entry.value,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: _labels[entry.key]),
              ),
          ],
        ),
        const SizedBox(height: 16),
        BlocConsumer<ManualDiagnosisCubit, ManualDiagnosisState>(
          listener: (ctx, state) {
            if (state.state == LoadState.error && state.error != null) {
              ScaffoldMessenger.of(ctx)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.error!)));
            }
          },
          builder: (ctx, state) {
            final busy = state.state == LoadState.loading;
            return Column(
              children: [
                FilledButton.icon(
                  onPressed: busy ? null : _run,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.biotech),
                  label: Text('${context.tr('run_diagnosis')}  ·  5 ⚡'),
                ),
                if (state.result != null) ...[
                  const SizedBox(height: 16),
                  DiagnosisCard(diagnosis: state.result!),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
