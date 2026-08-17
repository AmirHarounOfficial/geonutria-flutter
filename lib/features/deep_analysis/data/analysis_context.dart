import 'dart:convert';

import 'package:equatable/equatable.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The option keys the backend's `build_rag_prompt` reads.
///
/// These are keys, not labels: the prompt builder matches on them and falls
/// back to its own defaults for anything missing, so they must stay identical
/// to the web's `GlobalContextBar`. Labels are looked up per locale in
/// `app_strings.dart` under `ctx_<key>`.
class FarmContextOptions {
  const FarmContextOptions._();

  static const crops = [
    'wheat',
    'rice',
    'maize',
    'cotton',
    'sugarcane',
    'berseem',
    'citrus',
    'tomatoes',
    'potatoes',
    'sugarBeet',
    'strawberries',
    'pomegranates',
    'dates',
    'onions',
    'beans',
    'grapes',
    'mangoes',
  ];

  static const locations = [
    'Upper Egypt',
    'Lower Egypt (Delta)',
    'Canal Zone',
    'Sinai',
    'New Valley & Oases',
    'Cairo',
    'Giza',
    'Alexandria',
    'Faiyum',
    'Beheira',
    'Sharqia',
    'Dakahlia',
    'Gharbia',
    'Menofia',
    'Qalyubia',
    'Ismailia',
    'Suez',
    'Port Said',
    'Matrouh',
    'Red Sea',
    'Asyut',
    'Sohag',
    'Qena',
    'Luxor',
    'Aswan',
    'Minya',
    'Beni Suef',
  ];

  static const seasons = ['winter', 'spring', 'summer', 'autumn'];

  static const irrigationTypes = ['drip', 'sprinkler', 'flood', 'pivot'];

  static const soilTypes = ['clay', 'sandy', 'calcareous', 'saline', 'silty'];

  static const analysisDepths = ['executive', 'standard', 'comprehensive'];

  /// Typical consumption in m³/Feddan/Week, used to prefill the water field
  /// when an irrigation type is picked.
  static const waterBaselines = <String, double>{
    'drip': 25,
    'sprinkler': 35,
    'flood': 50,
    'pivot': 30,
  };
}

/// The farm context sent alongside sensor and weather readings.
///
/// Every field is optional — the backend substitutes a documented default for
/// anything blank and tells the user which assumptions it made, so a user who
/// fills in nothing still gets a usable report.
class AnalysisContext extends Equatable {
  const AnalysisContext({
    this.cropType = '',
    this.cropVariety = '',
    this.location = '',
    this.season = '',
    this.irrigationType = '',
    this.waterQuantity = '',
    this.soilType = '',
    this.analysisDepth = '',
  });

  final String cropType;

  /// Free text: the web offers suggestions per crop but accepts custom entry,
  /// and the variety list is far too large to be worth mirroring here.
  final String cropVariety;

  final String location;
  final String season;
  final String irrigationType;
  final String waterQuantity;
  final String soilType;
  final String analysisDepth;

  bool get isEmpty =>
      cropType.isEmpty &&
      cropVariety.isEmpty &&
      location.isEmpty &&
      season.isEmpty &&
      irrigationType.isEmpty &&
      waterQuantity.isEmpty &&
      soilType.isEmpty &&
      analysisDepth.isEmpty;

  /// How many of the fields the prompt builder defaults are actually set.
  int get filledCount => [
    cropType,
    cropVariety,
    location,
    season,
    irrigationType,
    waterQuantity,
    soilType,
  ].where((v) => v.isNotEmpty).length;

  AnalysisContext copyWith({
    String? cropType,
    String? cropVariety,
    String? location,
    String? season,
    String? irrigationType,
    String? waterQuantity,
    String? soilType,
    String? analysisDepth,
  }) => AnalysisContext(
    cropType: cropType ?? this.cropType,
    cropVariety: cropVariety ?? this.cropVariety,
    location: location ?? this.location,
    season: season ?? this.season,
    irrigationType: irrigationType ?? this.irrigationType,
    waterQuantity: waterQuantity ?? this.waterQuantity,
    soilType: soilType ?? this.soilType,
    analysisDepth: analysisDepth ?? this.analysisDepth,
  );

  /// Only non-empty fields are sent: the backend treats a missing key and an
  /// empty string alike, but omitting them keeps the prompt free of noise.
  Map<String, dynamic> toJson() => {
    if (cropType.isNotEmpty) 'cropType': cropType,
    if (cropVariety.isNotEmpty) 'cropVariety': cropVariety,
    if (location.isNotEmpty) 'location': location,
    if (season.isNotEmpty) 'season': season,
    if (irrigationType.isNotEmpty) 'irrigationType': irrigationType,
    if (waterQuantity.isNotEmpty) 'waterQuantity': waterQuantity,
    if (soilType.isNotEmpty) 'soilType': soilType,
    if (analysisDepth.isNotEmpty) 'analysisDepth': analysisDepth,
  };

  factory AnalysisContext.fromJson(Map<String, dynamic> j) => AnalysisContext(
    cropType: j['cropType']?.toString() ?? '',
    cropVariety: j['cropVariety']?.toString() ?? '',
    location: j['location']?.toString() ?? '',
    season: j['season']?.toString() ?? '',
    irrigationType: j['irrigationType']?.toString() ?? '',
    waterQuantity: j['waterQuantity']?.toString() ?? '',
    soilType: j['soilType']?.toString() ?? '',
    analysisDepth: j['analysisDepth']?.toString() ?? '',
  );

  @override
  List<Object?> get props => [
    cropType,
    cropVariety,
    location,
    season,
    irrigationType,
    waterQuantity,
    soilType,
    analysisDepth,
  ];
}

/// Persists the farm context between runs, mirroring the web's use of
/// localStorage — it describes the farm, not the reading, so re-entering it on
/// every analysis would be busywork.
class AnalysisContextStore {
  AnalysisContextStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _key = 'geonutria_farm_context';

  Future<AnalysisContext> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return const AnalysisContext();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const AnalysisContext();
      return AnalysisContext.fromJson(decoded.cast<String, dynamic>());
    } catch (_) {
      // A corrupt entry should not block the feature — fall back to blank,
      // which the backend fills with its defaults anyway.
      return const AnalysisContext();
    }
  }

  Future<void> write(AnalysisContext ctx) =>
      _storage.write(key: _key, value: jsonEncode(ctx.toJson()));
}
