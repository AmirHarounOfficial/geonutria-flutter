import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../auth/bloc/auth_cubit.dart';
import '../deep_analysis/data/analysis_context.dart';
import 'pdf_saver.dart';
import 'report_store.dart';

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

  final _sections = {for (final key in ReportStore.sections.keys) key: true};
  String? _reportLanguage;

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

  Future<Map<String, dynamic>> _buildReportPayload(
    ApiClient api,
    String lang,
  ) async {
    final uid = context.read<AuthCubit>().state.userId;
    if (uid == null) throw StateError('Not signed in');
    final payload = api.reports.payload(
      userId: uid,
      lang: lang,
      farmName: _farmName.text.trim().isEmpty
          ? context.ui('Smart Farm')
          : _farmName.text.trim(),
      farmerName: _farmerName.text.trim().isEmpty
          ? context.ui('Farm Manager')
          : _farmerName.text.trim(),
      selected: _sections.entries
          .where((e) => e.value)
          .map((e) => e.key)
          .toSet(),
    );
    var imageBytes = 0;
    if ((payload['options'] as Map)['include_device_map'] == true) {
      final imagery = <Map<String, dynamic>>[];
      for (final raw in payload['device_imagery'] as List? ?? []) {
        final d = Map<String, dynamic>.from(raw);
        final lat = (d['latitude'] as num).toDouble();
        final lon = (d['longitude'] as num).toDouble();
        final cosine = math.cos(lat * math.pi / 180);
        final halfSpan = 156543.03392 * cosine / math.pow(2, 17) * 1024 / 2;
        final dLat = halfSpan / 111320;
        final dLon = halfSpan / (111320 * math.max(.05, cosine));
        final url = Uri.https(
          'server.arcgisonline.com',
          '/ArcGIS/rest/services/World_Imagery/MapServer/export',
          {
            'bbox': '${lon - dLon},${lat - dLat},${lon + dLon},${lat + dLat}',
            'bboxSR': '4326',
            'imageSR': '3857',
            'size': '1024,1024',
            'format': 'jpg',
            'transparent': 'false',
            'f': 'image',
          },
        );
        final image = await api.reportImage(url.toString());
        final fits = image != null && imageBytes + image.length < 5500000;
        if (fits) imageBytes += image.length;
        imagery.add({
          ...d,
          'image_base64': fits ? image : null,
          'unavailable': !fits,
          'captured_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      payload['device_imagery'] = imagery;
    }
    if ((payload['options'] as Map)['include_satellite'] == true) {
      final transformed = <String, dynamic>{};
      final indices = payload['satellite_data'] as Map? ?? {};
      for (final entry in indices.entries) {
        if (entry.value is! Map) continue;
        final index = entry.value as Map;
        for (final slot in ['current', 'past']) {
          final image = await api.reportImage(index['${slot}_url']?.toString());
          final withinBudget =
              image != null && imageBytes + image.length < 5500000;
          if (withinBudget) imageBytes += image.length;
          transformed['${slot == 'current' ? 'new' : 'old'}_${entry.key}'] = {
            'map': withinBudget ? image : null,
            'unavailable': !withinBudget,
            'val': index['${slot}_val'],
            'insight': AppLocalizations(
              Locale(lang),
            ).tr('sat_${index['${slot}_insight'] ?? 'no_data'}'),
          };
        }
      }
      payload['satellite_data'] = transformed;
    }
    return payload;
  }

  Future<void> _generateReport() async {
    final api = context.read<ApiClient>();
    setState(() => _busy = true);
    try {
      final lang = context.locale.languageCode;
      final payload = await _buildReportPayload(api, lang);
      final bytes = await api.postPdf('/generate-report', body: payload);
      if (!mounted || lang != context.locale.languageCode) return;
      context.read<AuthCubit>().refreshCredits();
      setState(() {
        _reportLanguage = lang;
        _pdfBytes = bytes;
        _generatedAt = DateTime.now();
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(context.ui('Report generated successfully!')),
            ),
          );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('error_generic'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareReport({bool emailOnly = false}) async {
    if (_pdfBytes == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(context.ui('Please generate the report first.')),
          ),
        );
      return;
    }
    try {
      if (emailOnly) {
        await sharePdfViaEmail(
          _pdfBytes!,
          'geonutria_farm_report.pdf',
          title: context.ui('GeoNutria Farm Report'),
        );
      } else {
        await sharePdf(
          _pdfBytes!,
          'geonutria_farm_report.pdf',
          title: context.ui('GeoNutria Farm Report'),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('error_generic'))));
    }
  }

  Future<void> _downloadReport() async {
    if (_pdfBytes == null) return;
    try {
      final savedPath = await savePdf(
        _pdfBytes!,
        'geonutria_farm_report.pdf',
        title: context.ui('Save Report PDF'),
      );
      if (savedPath == null) return;
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              savedPath.isNotEmpty
                  ? '${context.ui('Report saved to')} $savedPath'
                  : context.ui('Report downloaded successfully'),
            ),
          ),
        );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(context.tr('error_generic'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<ApiClient>().reports;
    final lang = context.locale.languageCode;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final available = store.available(lang);
        return ListView(
          padding: EdgeInsets.all(16),
          children: [
            Text(
              context.ui('Generate & Share PDF Report'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 12),
            TextField(
              controller: _farmName,
              onChanged: (_) => setState(() => _pdfBytes = null),
              decoration: InputDecoration(
                labelText: context.ui('Farm Name'),
                prefixIcon: Icon(Icons.agriculture),
              ),
            ),
            SizedBox(height: 12),
            TextField(
              controller: _farmerName,
              onChanged: (_) => setState(() => _pdfBytes = null),
              decoration: InputDecoration(
                labelText: context.ui('Farmer / Reporter Name'),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            SizedBox(height: 16),
            Text(
              context.ui('Report Sections'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final entry in _sections.entries)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.ui(ReportStore.sections[entry.key]!)),
                value: entry.value && available.contains(entry.key),
                subtitle: available.contains(entry.key)
                    ? null
                    : Text(
                        context.ui(
                          'Run this feature in the selected language first.',
                        ),
                      ),
                onChanged: _busy || !available.contains(entry.key)
                    ? null
                    : (v) => setState(() {
                        _sections[entry.key] = v ?? false;
                        _pdfBytes = null;
                      }),
              ),
            SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  _busy ||
                      !_sections.entries.any(
                        (e) => e.value && available.contains(e.key),
                      )
                  ? null
                  : _generateReport,
              icon: _busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.picture_as_pdf),
              label: Text(context.ui('Generate Report  ·  5 ⚡')),
            ),
            if (_pdfBytes != null && _reportLanguage == lang) ...[
              SizedBox(height: 20),
              Card(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text(
                            '${context.ui('Report Ready')} (${(_pdfBytes!.length / 1024).toStringAsFixed(1)} KB)',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      if (_generatedAt != null) ...[
                        SizedBox(height: 4),
                        Text(
                          '${context.ui('Generated on')} ${_generatedAt!.hour.toString().padLeft(2, '0')}:${_generatedAt!.minute.toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _shareReport(emailOnly: false),
                              icon: Icon(Icons.share),
                              label: Text(context.ui('Share')),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _downloadReport,
                              icon: Icon(Icons.download),
                              label: Text(context.ui('Download')),
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
      },
    );
  }
}
