import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../auth/bloc/auth_cubit.dart';
import '../deep_analysis/data/analysis_context.dart';
import 'pdf_saver.dart';

/// Generates a PDF farm report via `POST /generate-report` with aggregated farm
/// context & sensor telemetry, previews it, and shares it.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _farmName = TextEditingController();
  final _farmerName = TextEditingController();
  bool _busy = false;
  Uint8List? _pdfBytes;
  DateTime? _generatedAt;

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
  void initState() {
    super.initState();
    _loadFarmContext();
  }

  Future<void> _loadFarmContext() async {
    final ctx = await AnalysisContextStore().read();
    if (!mounted) return;
    if (ctx.location.isNotEmpty && _farmName.text.isEmpty) {
      _farmName.text = ctx.location;
    }
  }

  @override
  void dispose() {
    _farmName.dispose();
    _farmerName.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _buildReportPayload(ApiClient api, String lang) async {
    final uid = context.read<AuthCubit>().state.userId ?? api.userId ?? 1;

    Map<String, dynamic> iotData = {
      "Nitrogen_Level": 80,
      "Phosphorus_Level": 40,
      "Potassium_Level": 45,
      "Soil_Moisture": 65,
      "Humidity": 60,
      "Ambient_Temperature": 28,
      "Soil_pH": 6.5,
      "Soil_Salinity": 1.2
    };

    try {
      final devices = await api.get('/my-devices', query: api.authQuery());
      if (devices is List && devices.isNotEmpty) {
        final devId = devices.first['id'];
        final hist = await api.get('/iot-history/$devId', query: {'limit': 1});
        if (hist is Map && hist['status'] == 'success' && hist['data'] is List && (hist['data'] as List).isNotEmpty) {
          final reading = (hist['data'] as List).first as Map;
          iotData = {
            "Nitrogen_Level": reading['nitrogen'] ?? 80,
            "Phosphorus_Level": reading['phosphorus'] ?? 40,
            "Potassium_Level": reading['potassium'] ?? 45,
            "Soil_Moisture": reading['humidity'] ?? 65,
            "Humidity": reading['humidity'] ?? 60,
            "Ambient_Temperature": reading['temperature'] ?? 28,
            "Soil_pH": reading['ph'] ?? 6.5,
          };
        }
      }
    } catch (_) {}

    return {
      'user_id': uid,
      'options': {..._sections, 'language': lang},
      'farm_name': _farmName.text.trim().isEmpty ? 'GeoNutria Smart Farm' : _farmName.text.trim(),
      'farmer_name': _farmerName.text.trim().isEmpty ? 'Farm Manager' : _farmerName.text.trim(),
      'iot_data': iotData,
      'iot_ai_status': 'Optimal',
      'iot_ai_confidence': 95,
      'crop_inputs': {
        'Nitrogen': '${iotData['Nitrogen_Level']} mg/kg',
        'Phosphorus': '${iotData['Phosphorus_Level']} mg/kg',
        'Potassium': '${iotData['Potassium_Level']} mg/kg',
        'Temperature': '${iotData['Ambient_Temperature']} °C',
        'Humidity': '${iotData['Humidity']}%',
        'Soil pH': '${iotData['Soil_pH']}',
        'Rainfall': '200 mm'
      },
      'crop_recommendations': [
        {'crop': 'Wheat', 'confidence': 94},
        {'crop': 'Maize', 'confidence': 88},
        {'crop': 'Rice', 'confidence': 82}
      ],
      'yield_inputs': {
        'Crop': 'Wheat',
        'Nitrogen': iotData['Nitrogen_Level'],
        'Phosphorus': iotData['Phosphorus_Level'],
        'Potassium': iotData['Potassium_Level'],
        'Temperature': iotData['Ambient_Temperature'],
        'Humidity': iotData['Humidity'],
        'pH': iotData['Soil_pH']
      },
      'yield_prediction': {'predicted_yield_kg_per_ha': 3450},
      'ai_consultant_text': lang == 'ar'
          ? 'تشخيص المزرعة الشامل:\n١. مستويات المغذيات (النيتروجين، الفسفور، البوتاسيوم) ورطوبة التربة ضمن النطاق الأمثل للمحاصيل الموسمية.\n٢. نظام الري الموصى به: الري بالتنقيط بمعدل ٢٥ م³/فدان/أسبوع.\n٣. خطر الأمراض: منخفض. يوصى بالمتابعة الميدانية الدورية.'
          : 'Integrated Farm Diagnosis:\n1. Soil nutrients (N, P, K) and soil moisture readings are within optimal range for seasonal crops.\n2. Recommended Irrigation: Drip irrigation 25 m³/Feddan/Week.\n3. Disease Risk: Low. Continue routine field monitoring.',
    };
  }

  Future<void> _generateReport() async {
    final api = context.read<ApiClient>();
    setState(() => _busy = true);
    try {
      final lang = context.locale.languageCode;
      final payload = await _buildReportPayload(api, lang);
      final bytes = await api.postPdf('/generate-report', body: payload);
      setState(() {
        _pdfBytes = bytes;
        _generatedAt = DateTime.now();
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Report generated successfully!')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Report generation failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareReport({bool emailOnly = false}) async {
    if (_pdfBytes == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Please generate the report first.')));
      return;
    }
    try {
      if (emailOnly) {
        await sharePdfViaEmail(_pdfBytes!, 'geonutria_farm_report.pdf');
      } else {
        await savePdf(_pdfBytes!, 'geonutria_farm_report.pdf');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Share failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Generate & Share PDF Report',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        TextField(
          controller: _farmName,
          decoration: const InputDecoration(
            labelText: 'Farm Name',
            prefixIcon: Icon(Icons.agriculture),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _farmerName,
          decoration: const InputDecoration(
            labelText: 'Farmer / Reporter Name',
            prefixIcon: Icon(Icons.person),
          ),
        ),
        const SizedBox(height: 16),
        Text('Report Sections', style: Theme.of(context).textTheme.titleSmall),
        for (final entry in _sections.entries)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_sectionLabels[entry.key] ?? entry.key),
            value: entry.value,
            onChanged: (v) => setState(() => _sections[entry.key] = v ?? false),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _generateReport,
          icon: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.picture_as_pdf),
          label: const Text('Generate Report  ·  5 ⚡'),
        ),
        if (_pdfBytes != null) ...[
          const SizedBox(height: 20),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'Report Ready (${(_pdfBytes!.length / 1024).toStringAsFixed(1)} KB)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (_generatedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Generated on ${_generatedAt!.hour.toString().padLeft(2, '0')}:${_generatedAt!.minute.toString().padLeft(2, '0')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _shareReport(emailOnly: false),
                          icon: const Icon(Icons.share),
                          label: const Text('Quick Share'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _shareReport(emailOnly: true),
                          icon: const Icon(Icons.email_outlined),
                          label: const Text('Share Email'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

