import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import 'pdf_saver.dart';

/// Generates a PDF farm report via `POST /generate-report` and shares it.
///
/// The web app accumulates live AI results into the report payload across
/// screens; on mobile we send the farm/farmer identity, language and section
/// toggles, and the backend fills sensible defaults for any section without
/// data. (Cross-feature result aggregation can be layered on later.)
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _farmName = TextEditingController();
  final _farmerName = TextEditingController();
  bool _busy = false;

  final _sections = <String, bool>{
    'include_iot': true,
    'include_leaf_ai': true,
    'include_soil_ai': true,
    'include_crop_ai': true,
    'include_yield_ai': true,
    'include_consultant': true,
    'include_satellite': true,
  };

  static const _sectionLabels = {
    'include_iot': 'IoT sensors',
    'include_leaf_ai': 'Leaf diagnosis',
    'include_soil_ai': 'Soil analysis',
    'include_crop_ai': 'Crop recommendation',
    'include_yield_ai': 'Yield prediction',
    'include_consultant': 'AI consultant',
    'include_satellite': 'Satellite',
  };

  @override
  void dispose() {
    _farmName.dispose();
    _farmerName.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final api = context.read<ApiClient>();
    setState(() => _busy = true);
    try {
      final lang = context.locale.languageCode;
      final bytes = await api.postPdf('/generate-report', body: {
        'options': {..._sections, 'language': lang},
        'farm_name': _farmName.text.trim().isEmpty ? 'My Farm' : _farmName.text.trim(),
        'farmer_name':
            _farmerName.text.trim().isEmpty ? 'Farmer' : _farmerName.text.trim(),
      });
      await savePdf(bytes, 'geonutria_report.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Report failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Generate a PDF report',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _farmName,
          decoration: const InputDecoration(labelText: 'Farm name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _farmerName,
          decoration: const InputDecoration(labelText: 'Farmer name'),
        ),
        const SizedBox(height: 16),
        Text('Sections', style: Theme.of(context).textTheme.titleSmall),
        for (final entry in _sections.entries)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_sectionLabels[entry.key] ?? entry.key),
            value: entry.value,
            onChanged: (v) => setState(() => _sections[entry.key] = v ?? false),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _generate,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.picture_as_pdf),
          label: const Text('Generate & share'),
        ),
      ],
    );
  }
}
