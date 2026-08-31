import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../core/network/api_client.dart';
import '../auth/bloc/auth_cubit.dart';
import '../dashboard/bloc/history_cubit.dart' show LoadState;
import '../deep_analysis/data/analysis_context.dart';
import 'yield_cubit.dart';

/// Predicts crop yield from environment and telemetry inputs, displaying a streaming AI diagnosis report.
class YieldScreen extends StatelessWidget {
  const YieldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => YieldCubit(
        ctx.read<ApiClient>(),
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
  static const _crops = ['Rice', 'Maize', 'Chickpea', 'Cotton', 'Wheat', 'Sugarcane', 'Tomatoes', 'Potatoes'];
  String _crop = 'Rice';
  bool _thinkingExpanded = true;

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
                if (bctx.mounted) Navigator.of(bctx).pop();
                if (mounted) _loadFarmContext();
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
    final lang = Localizations.localeOf(context).languageCode;
    context.read<YieldCubit>().predict(
          crop: _crop,
          n: _i('n'),
          p: _i('p'),
          k: _i('k'),
          temperature: _i('temperature'),
          humidity: _i('humidity'),
          ph: _d('ph'),
          rainfall: _i('rainfall'),
          lang: lang,
          context: _farmContext,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocListener<YieldCubit, YieldState>(
      listenWhen: (a, b) => a.error != b.error,
      listener: (ctx, state) {
        if (state.error != null) {
          ScaffoldMessenger.of(ctx)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      child: BlocBuilder<YieldCubit, YieldState>(
        builder: (context, state) {
          final busy = state.streaming || state.state == LoadState.loading;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Header Title
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.trending_up, color: Colors.amber, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Yield Prediction Model',
                          style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Estimate total crop harvest volume utilizing environmental ML analytics.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Farm Context Card
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, size: 18),
                          const SizedBox(width: 8),
                          Text('Global Farm Context',
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _editFarmContext(context),
                            icon: const Icon(Icons.edit, size: 14),
                            label: const Text('Edit Context', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.grass, size: 12),
                            label: Text(
                              'Crop: ${_farmContext.cropType.isNotEmpty ? _farmContext.cropType : "Unspecified"}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.terrain, size: 12),
                            label: Text(
                              'Soil: ${_farmContext.soilType.isNotEmpty ? _farmContext.soilType : "Unspecified"}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          if (_farmContext.location.isNotEmpty)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.place, size: 12),
                              label: Text(
                                'Loc: ${_farmContext.location}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          if (_farmContext.irrigationType.isNotEmpty)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.water_drop, size: 12),
                              label: Text(
                                'Irri: ${_farmContext.irrigationType}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Crop Selection
              DropdownButtonFormField<String>(
                value: _crops.contains(_crop) ? _crop : _crops.first,
                decoration: const InputDecoration(
                  labelText: 'Crop Selection',
                  prefixIcon: Icon(Icons.grass),
                ),
                items: [
                  for (final c in _crops)
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: busy ? null : (v) => setState(() => _crop = v ?? 'Rice'),
              ),
              const SizedBox(height: 16),

              // Environmental Telemetry Section
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.sensors, color: colorScheme.primary, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'Soil & Environmental Telemetry',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: busy ? null : _syncIoTData,
                            icon: const Icon(Icons.sync, size: 14),
                            label: const Text('Auto-fill IoT Data', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _ctl.length,
                        itemBuilder: (ctx, i) {
                          final e = _ctl.entries.elementAt(i);
                          return TextField(
                            controller: e.value,
                            enabled: !busy,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (v) => _validateField(e.key, v),
                            decoration: InputDecoration(
                              labelText: _labels[e.key],
                              errorText: _errors[e.key],
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Calculate Prediction Button
              FilledButton.icon(
                onPressed: busy ? null : _predict,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.amber.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.analytics, size: 22),
                label: Text(
                  busy ? 'Computing Yield Prediction...' : 'Calculate Prediction  ·  5 ⚡',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),

              // Diagnostics Panel & AI Yield Prediction Results
              if (state.streaming || state.isThinking || state.thinking.isNotEmpty || state.aiReport.isNotEmpty) ...[
                _buildDiagnosticsHeader(context, state),
                const SizedBox(height: 12),

                // Thinking / Reasoning Accordion (<think>...) matching Web DiagnosticsPanel
                if (state.isThinking || state.thinking.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    color: Colors.amber.withOpacity(0.06),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: ExpansionTile(
                      key: ValueKey('thinking-${state.isThinking}-${state.thinking.isNotEmpty}'),
                      initiallyExpanded: _thinkingExpanded,
                      onExpansionChanged: (v) => setState(() => _thinkingExpanded = v),
                      leading: Icon(Icons.auto_awesome, color: Colors.amber.shade800, size: 20),
                      title: Row(
                        children: [
                          Text(
                            state.isThinking ? 'Reasoning…' : 'Thinking Process',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                          if (state.isThinking) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(color: Colors.amber.shade700, width: 3),
                              ),
                            ),
                            child: Text(
                              state.thinking.isNotEmpty
                                  ? state.thinking
                                  : 'Analyzing environmental vectors, soil parameters, and crop yield models...',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                                fontStyle: FontStyle.italic,
                                color: theme.textTheme.bodySmall?.color?.withOpacity(0.85),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // AI Agronomist Yield Prediction Report Markdown
                if (state.aiReport.isNotEmpty) ...[
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: MarkdownBody(
                        data: state.aiReport,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                          h1: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                          h2: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                          p: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                        ),
                      ),
                    ),
                  ),
                ],
              ],

              if (state.state == LoadState.error && state.error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.error.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colorScheme.error),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: TextStyle(color: colorScheme.error, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildDiagnosticsHeader(BuildContext context, YieldState state) {
    final isDone = !state.streaming && state.state == LoadState.loaded;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDone ? Colors.green.withOpacity(0.12) : Colors.amber.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDone ? Colors.green.withOpacity(0.3) : Colors.amber.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDone ? Icons.check_circle_outline : Icons.sync,
                size: 16,
                color: isDone ? Colors.green.shade800 : Colors.amber.shade800,
              ),
              const SizedBox(width: 6),
              Text(
                isDone ? 'ANALYSIS COMPLETE' : 'AI STREAMING...',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: isDone ? Colors.green.shade800 : Colors.amber.shade800,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (isDone)
          TextButton.icon(
            onPressed: () => context.read<YieldCubit>().resetAnalysis(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('New Analysis', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }
}
