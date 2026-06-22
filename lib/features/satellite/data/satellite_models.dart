import '../../../core/config/env.dart';

/// One vegetation index package from `/satellite-analysis`.
class IndexResult {
  const IndexResult({
    required this.key,
    required this.currentUrl,
    required this.pastUrl,
    required this.currentVal,
    required this.pastVal,
    required this.currentInsight,
    required this.pastInsight,
  });

  final String key; // ndvi, ndmi, ndre, gndvi, ndwi, savi
  final String? currentUrl;
  final String? pastUrl;
  final double currentVal;
  final double pastVal;
  final String currentInsight;
  final String pastInsight;

  String? get currentImage => currentUrl == null ? null : Env.resolveMedia(currentUrl);
  String? get pastImage => pastUrl == null ? null : Env.resolveMedia(pastUrl);
  double get delta => currentVal - pastVal;

  factory IndexResult.fromJson(String key, Map<String, dynamic> j) =>
      IndexResult(
        key: key,
        currentUrl: j['current_url'] as String?,
        pastUrl: j['past_url'] as String?,
        currentVal: (j['current_val'] as num?)?.toDouble() ?? 0,
        pastVal: (j['past_val'] as num?)?.toDouble() ?? 0,
        currentInsight: (j['current_insight'] ?? '').toString(),
        pastInsight: (j['past_insight'] ?? '').toString(),
      );
}

/// Full result of `/satellite-analysis`.
class SatelliteResult {
  const SatelliteResult({
    required this.dateCurrent,
    required this.datePast,
    required this.areaKm2,
    required this.indices,
    this.rgbCurrentUrl,
    this.rgbPastUrl,
  });

  final String dateCurrent;
  final String datePast;
  final double areaKm2;
  final List<IndexResult> indices;
  final String? rgbCurrentUrl;
  final String? rgbPastUrl;

  String? get rgbCurrent => rgbCurrentUrl == null ? null : Env.resolveMedia(rgbCurrentUrl);
  String? get rgbPast => rgbPastUrl == null ? null : Env.resolveMedia(rgbPastUrl);

  static const _order = ['ndvi', 'ndmi', 'ndre', 'gndvi', 'ndwi', 'savi'];

  factory SatelliteResult.fromJson(Map<String, dynamic> j) {
    final meta = (j['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final idx = (j['indices'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rgb = (j['rgb'] as Map?)?.cast<String, dynamic>() ?? const {};
    return SatelliteResult(
      dateCurrent: (meta['date_current'] ?? 'N/A').toString(),
      datePast: (meta['date_past'] ?? 'N/A').toString(),
      areaKm2: (meta['area_km2'] as num?)?.toDouble() ?? 0,
      indices: [
        for (final key in _order)
          if (idx[key] is Map)
            IndexResult.fromJson(key, (idx[key] as Map).cast<String, dynamic>()),
      ],
      rgbCurrentUrl: rgb['current_url'] as String?,
      rgbPastUrl: rgb['past_url'] as String?,
    );
  }
}
