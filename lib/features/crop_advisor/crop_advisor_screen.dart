import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/api_client.dart';
import '../../core/widgets/image_pick_sheet.dart';
import '../../core/widgets/picked_image.dart';
import '../auth/bloc/auth_cubit.dart';
import '../dashboard/bloc/history_cubit.dart' show LoadState;
import '../deep_analysis/data/analysis_context.dart';
import 'crop_advisor_cubit.dart';

/// Crop Recommendation Screen matching CropRecommendView.js in server-frontend:
/// 1. Header with Title & Subtitle.
/// 2. Global Farm Context Card with Modal Editor.
/// 3. Step 1: Soil Origin (Soil Image upload & classification via /classify-soil SSE stream).
/// 4. Step 2: Local Environment Telemetry (N, P, K, Temp, Humidity, pH + Auto-fill IoT).
/// 5. Diagnostics Panel: Streaming Reasoning process & Markdown Agronomist Report via /recommend-crops SSE.
class CropAdvisorScreen extends StatelessWidget {
  const CropAdvisorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => CropAdvisorCubit(
        ctx.read<ApiClient>(),
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
  final _ctl = {
    'n': TextEditingController(text: '0'),
    'p': TextEditingController(text: '0'),
    'k': TextEditingController(text: '0'),
    'temperature': TextEditingController(text: '25'),
    'humidity': TextEditingController(text: '50'),
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
    setState(() => _farmContext = ctx);
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
            Text('Edit Global Farm Context', style: Theme.of(bctx).textTheme.titleMedium),
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
                if (bctx.mounted) Navigator.of(bctx).pop();
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
            _ctl['n']!.text = (reading['nitrogen'] ?? 0).toString();
            _ctl['p']!.text = (reading['phosphorus'] ?? 0).toString();
            _ctl['k']!.text = (reading['potassium'] ?? 0).toString();
            _ctl['temperature']!.text = (reading['temperature'] ?? 25).toString();
            _ctl['humidity']!.text = (reading['humidity'] ?? 50).toString();
            _ctl['ph']!.text = (reading['ph'] ?? 6.5).toString();
            _errors.clear();
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('IoT telemetry auto-filled successfully!')),
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
          SnackBar(content: Text('IoT Sync Error: $e')),
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
      setState(() => _errors[key] = 'Required');
      return;
    }
    final val = double.tryParse(raw);
    if (val == null) {
      setState(() => _errors[key] = 'Invalid number');
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
    }
  }

  void _clearSoil() {
    setState(() => _soilFile = null);
    context.read<CropAdvisorCubit>().clearSoil();
  }

  void _recommend(CropAdvisorState state) {
    final effectiveSoil = state.soilType.isNotEmpty
        ? state.soilType
        : (_farmContext.soilType.isNotEmpty ? _farmContext.soilType : 'Not specified');

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
          soilType: effectiveSoil,
          context: _farmContext,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return BlocListener<CropAdvisorCubit, CropAdvisorState>(
      listenWhen: (a, b) => a.error != b.error,
      listener: (ctx, state) {
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
              // Header Title & Description
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B8F71).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.grass, color: Color(0xFF6B8F71), size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Crop Recommendation',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Discover optimal crop pairings based on soil analytics and environmental factors.',
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

              // Global Farm Context Bar
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
                          Text(
                            'Global Farm Context',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
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
                            avatar: const Icon(Icons.terrain, size: 12),
                            label: Text(
                              'Soil: ${_farmContext.soilType.isNotEmpty ? _farmContext.soilType : "Unspecified"}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            avatar: const Icon(Icons.grass, size: 12),
                            label: Text(
                              'Crop: ${_farmContext.cropType.isNotEmpty ? _farmContext.cropType : "Unspecified"}',
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

              // Step 1: Soil Origin (Upload & Classification)
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
                          Text(
                            'Step 1 · Soil Origin',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (_soilFile != null && state.soilState != LoadState.loading)
                            TextButton.icon(
                              onPressed: _clearSoil,
                              icon: const Icon(Icons.close, size: 16, color: Colors.red),
                              label: const Text('Clear', style: TextStyle(color: Colors.red, fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _pickSoil,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF6B8F71).withOpacity(0.5),
                              width: 1.5,
                            ),
                            color: const Color(0xFF6B8F71).withOpacity(0.05),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _soilFile == null
                              ? Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF6B8F71)),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Upload Soil Image',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF6B8F71),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Tap to capture or select a soil photo (5 ⚡)',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Stack(
                                  children: [
                                    Positioned.fill(child: PickedImage(file: _soilFile!)),
                                    if (state.soilState == LoadState.loading)
                                      Positioned.fill(
                                        child: Container(
                                          color: Colors.black54,
                                          child: const Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircularProgressIndicator(color: Color(0xFFC47A2C)),
                                                SizedBox(height: 10),
                                                Text(
                                                  'SCANNING SOIL MATRIX...',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.2,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (state.soilType.isEmpty && state.soilState != LoadState.loading)
                                      Positioned.fill(
                                        child: Container(
                                          color: Colors.black26,
                                          child: Center(
                                            child: ElevatedButton.icon(
                                              onPressed: () => context
                                                  .read<CropAdvisorCubit>()
                                                  .classifySoil(_soilFile!),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF6B8F71),
                                                foregroundColor: Colors.white,
                                                shape: const StadiumBorder(),
                                              ),
                                              icon: const Icon(Icons.search, size: 18),
                                              label: const Text(
                                                'Identify Soil',
                                                style: TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (state.soilType.isNotEmpty && state.soilState != LoadState.loading)
                                      Positioned(
                                        bottom: 0,
                                        left: 0,
                                        right: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          color: Colors.black87,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'DETECTED SOIL',
                                                style: TextStyle(
                                                  color: Color(0xFF6B8F71),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 11,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                              Text(
                                                state.soilType,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ),
                      if (state.soilStreamContent.isNotEmpty || state.soilThinkingContent.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: colorScheme.outlineVariant),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.analytics_outlined, size: 16, color: Color(0xFF6B8F71)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Soil Identification Analysis',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (state.soilThinkingContent.isNotEmpty)
                                  Text(
                                    state.soilThinkingContent,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: 'monospace',
                                      fontStyle: FontStyle.italic,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                if (state.soilStreamContent.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  MarkdownBody(
                                    data: state.soilStreamContent,
                                    selectable: true,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Step 2: Local Environment Telemetry Grid
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
                              const Icon(Icons.electric_bolt, color: Color(0xFFC47A2C), size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'Step 2 · Local Environment',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          OutlinedButton.icon(
                            onPressed: _syncIoTData,
                            icon: const Icon(Icons.sync, size: 14),
                            label: const Text('Auto-fill IoT', style: TextStyle(fontSize: 12)),
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
                          childAspectRatio: 2.3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: _ctl.length,
                        itemBuilder: (ctx, i) {
                          final e = _ctl.entries.elementAt(i);
                          return TextField(
                            controller: e.value,
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

              // Get Recommendations Button
              FilledButton.icon(
                onPressed: state.streaming ? null : () => _recommend(state),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFFC47A2C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: state.streaming
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.psychology, size: 22),
                label: Text(
                  state.streaming ? 'Generating Agronomic Recommendations...' : 'Get Recommendations  ·  5 ⚡',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),

              // Results & Diagnostics Domain
              if (state.recState == LoadState.initial && !state.streaming && state.aiReport.isEmpty)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.grass, size: 40, color: colorScheme.outline),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Submit parameters to generate optimal crop yields.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // Status Header Bar
                Card(
                  elevation: 0,
                  color: state.streaming
                      ? const Color(0xFFC47A2C).withOpacity(0.1)
                      : const Color(0xFF6B8F71).withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: state.streaming
                          ? const Color(0xFFC47A2C).withOpacity(0.3)
                          : const Color(0xFF6B8F71).withOpacity(0.3),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              state.streaming ? Icons.sync : Icons.check_circle_outline,
                              size: 18,
                              color: state.streaming ? const Color(0xFFC47A2C) : const Color(0xFF6B8F71),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              state.streaming ? 'AI STREAMING...' : 'ANALYSIS COMPLETE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.8,
                                color: state.streaming ? const Color(0xFFC47A2C) : const Color(0xFF6B8F71),
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => context.read<CropAdvisorCubit>().resetAnalysis(),
                          child: const Text('New Analysis', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Reasoning / Thinking Process Accordion
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
                      initiallyExpanded: true,
                      leading: Icon(Icons.auto_awesome, color: Colors.amber.shade800, size: 20),
                      title: Row(
                        children: [
                          Text(
                            state.isThinking ? 'Thinking Process…' : 'Thinking Process',
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
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amber),
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
                                  : 'Analyzing soil matrix, environmental telemetry, and agronomic models...',
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

                // Agronomist Report Markdown Body
                if (state.aiReport.isNotEmpty)
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
                          h3: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.secondary,
                          ),
                          p: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
