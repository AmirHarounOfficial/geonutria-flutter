import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../bloc/history_cubit.dart' show LoadState;
import '../../bloc/manual_diagnosis_cubit.dart';
import 'diagnosis_card.dart';

/// One manual input: its label, the range it accepts, and its controller.
///
/// The range is what makes the diagnosis trustworthy — the model will happily
/// consume 28,000 °C and return a confident answer, so implausible values have
/// to be rejected before they reach it.
class _FieldSpec {
  _FieldSpec(this.key, this.label, this.min, this.max, String initial)
    : controller = TextEditingController(text: initial);

  final String key;
  final String label;
  final double min;
  final double max;
  final TextEditingController controller;

  double get value => double.tryParse(controller.text.trim()) ?? 0;

  String? validate(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return 'Required';
    final v = double.tryParse(text);
    if (v == null) return 'Numbers only';
    if (v < min || v > max) {
      return 'Must be ${_fmt(min)}–${_fmt(max)}';
    }
    return null;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  void dispose() => controller.dispose();
}

/// Lets the user enter sensor values by hand and run the AI health model
/// (mirrors the web "Manual entry" mode).
class ManualEntryForm extends StatefulWidget {
  const ManualEntryForm({super.key});

  @override
  State<ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<ManualEntryForm> {
  final _formKey = GlobalKey<FormState>();

  // Ranges are deliberately generous at the edges of what is physically
  // plausible in a field, rather than tight agronomic norms — the aim is to
  // catch typos and nonsense, not to argue with an unusual but real reading.
  late final List<_FieldSpec> _specs = [
    _FieldSpec('moisture', 'Soil Moisture (%)', 0, 100, '40'),
    _FieldSpec('soilTemp', 'Soil Temp (°C)', -20, 80, '25'),
    _FieldSpec('ambientTemp', 'Ambient Temp (°C)', -50, 70, '28'),
    _FieldSpec('humidity', 'Humidity (%)', 0, 100, '55'),
    _FieldSpec('ph', 'Soil pH', 0, 14, '6.5'),
    _FieldSpec('nitrogen', 'Nitrogen (mg/kg)', 0, 500, '50'),
    _FieldSpec('phosphorus', 'Phosphorus (mg/kg)', 0, 500, '40'),
    _FieldSpec('potassium', 'Potassium (mg/kg)', 0, 500, '45'),
    _FieldSpec('ec', 'EC (µS/cm)', 0, 20000, '500'),
  ];

  _FieldSpec _spec(String key) => _specs.firstWhere((s) => s.key == key);

  @override
  void dispose() {
    for (final s in _specs) {
      s.dispose();
    }
    super.dispose();
  }

  void _run() {
    // Blocks submission until every field holds a valid, in-range number.
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Fix the highlighted values first.')),
        );
      return;
    }
    context.read<ManualDiagnosisCubit>().run(
      moisture: _spec('moisture').value,
      soilTemp: _spec('soilTemp').value,
      ambientTemp: _spec('ambientTemp').value,
      humidity: _spec('humidity').value,
      ph: _spec('ph').value,
      nitrogen: _spec('nitrogen').value,
      phosphorus: _spec('phosphorus').value,
      potassium: _spec('potassium').value,
      ec: _spec('ec').value,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.tr('manual_entry'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the readings you have. Values outside a plausible range are '
            'rejected so the diagnosis stays meaningful.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _specs.length,
            // Fixed height rather than an aspect ratio, so an inline error
            // message has somewhere to go instead of overflowing the cell.
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 84,
              mainAxisSpacing: 8,
              crossAxisSpacing: 12,
            ),
            itemBuilder: (context, i) {
              final spec = _specs[i];
              return TextFormField(
                controller: spec.controller,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                // Stops letters reaching the field at all; the validator still
                // catches malformed numbers like "5.5.5" or a lone "-".
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
                ],
                validator: spec.validate,
                decoration: InputDecoration(
                  labelText: spec.label,
                  isDense: true,
                  errorMaxLines: 2,
                ),
              );
            },
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
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
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
      ),
    );
  }
}
