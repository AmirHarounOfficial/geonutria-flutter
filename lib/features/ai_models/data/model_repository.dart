import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';

/// Result of a leaf/palm diagnosis.
class LeafResult {
  const LeafResult({
    required this.diagnosis,
    required this.confidence,
    this.isolatedImage,
  });
  final String diagnosis;
  final double confidence; // 0-100
  final String? isolatedImage; // data:image/webp;base64,... (palm/general glow)
}

class SoilResult {
  const SoilResult({required this.soilType, required this.confidence});
  final String soilType;
  final double confidence; // 0-100
}

class CropRec {
  const CropRec({required this.crop, required this.confidence});
  final String crop;
  final double confidence; // 0-100
}

class PalmCountResult {
  const PalmCountResult({required this.count, this.annotatedImage});
  final int count;
  final String? annotatedImage; // data URI
}

/// Wraps the AI model endpoints in the FastAPI `models` router (all at root).
/// Image endpoints are multipart with fields `file` + `user_id`.
class ModelRepository {
  ModelRepository(this._api);

  final ApiClient _api;

  Future<MultipartFile> _multipart(XFile file) async {
    final bytes = await file.readAsBytes();
    return MultipartFile.fromBytes(bytes, filename: file.name);
  }

  /// Palm flow: `POST /diagnose-palm-disease` (seg + classify in one call).
  Future<LeafResult> diagnosePalm(int userId, XFile file) async {
    final data = await _api.upload(
      '/diagnose-palm-disease',
      files: {'file': await _multipart(file)},
      fields: {'user_id': userId},
    );
    final map = (data as Map).cast<String, dynamic>();
    if (map['status'] == 'error') {
      throw Exception(map['message'] ?? 'No palm leaf detected');
    }
    return LeafResult(
      diagnosis: '${map['diagnosis']}',
      confidence: (map['diagnosis_confidence'] as num?)?.toDouble() ?? 0,
      isolatedImage: map['isolated_mask_image'] as String?,
    );
  }

  /// General leaf flow: segment (for the glow image) then classify.
  Future<LeafResult> diagnoseGeneralLeaf(int userId, XFile file) async {
    String? glow;
    final segData = await _api.upload(
      '/segment-general-leaf',
      files: {'file': await _multipart(file)},
      fields: {'user_id': userId},
    );
    final segMap = (segData as Map).cast<String, dynamic>();
    if (segMap['status'] == 'error') {
      throw Exception(segMap['message'] ?? 'No leaves detected');
    }
    glow = segMap['isolated_mask_image'] as String?;

    final clsData = await _api.upload(
      '/diagnose-leaf',
      files: {'file': await _multipart(file)},
      fields: {'user_id': userId},
    );
    final clsMap = (clsData as Map).cast<String, dynamic>();
    return LeafResult(
      diagnosis: '${clsMap['diagnosis']}',
      confidence: (clsMap['confidence'] as num?)?.toDouble() ?? 0,
      isolatedImage: glow,
    );
  }

  /// `POST /classify-soil` (multipart).
  Future<SoilResult> classifySoil(int userId, XFile file) async {
    final data = await _api.upload(
      '/classify-soil',
      files: {'file': await _multipart(file)},
      fields: {'user_id': userId},
    );
    final map = (data as Map).cast<String, dynamic>();
    return SoilResult(
      soilType: '${map['soil_type']}',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
    );
  }

  /// `POST /recommend-crops` (JSON) — returns top 7 crops.
  Future<List<CropRec>> recommendCrops({
    required int userId,
    required double n,
    required double p,
    required double k,
    required double temperature,
    required double humidity,
    required double ph,
    required double rainfall,
    required String soilType,
  }) async {
    final data = await _api.post('/recommend-crops', body: {
      'N': n,
      'P': p,
      'K': k,
      'temperature': temperature,
      'humidity': humidity,
      'ph': ph,
      'rainfall': rainfall,
      'soil_type': soilType,
      'user_id': userId,
    });
    final map = (data as Map).cast<String, dynamic>();
    final list = map['top_7_crops'];
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => CropRec(
              crop: '${e['crop']}',
              confidence: (e['confidence'] as num?)?.toDouble() ?? 0,
            ))
        .toList();
  }

  /// `POST /predict-yield` (JSON) — returns kg/ha.
  Future<int> predictYield({
    required int userId,
    required String crop,
    required int n,
    required int p,
    required int k,
    required int temperature,
    required int humidity,
    required double ph,
    required int rainfall,
  }) async {
    final data = await _api.post('/predict-yield', body: {
      'Crop': crop,
      'N': n,
      'P': p,
      'K': k,
      'Temperature': temperature,
      'Humidity': humidity,
      'pH': ph,
      'Rainfall': rainfall,
      'user_id': userId,
    });
    final map = (data as Map).cast<String, dynamic>();
    return (map['predicted_yield_kg_per_ha'] as num?)?.toInt() ?? 0;
  }

  /// `POST /count-palm-trees` (multipart aerial image).
  Future<PalmCountResult> countPalms(int userId, XFile file) async {
    final data = await _api.upload(
      '/count-palm-trees',
      files: {'file': await _multipart(file)},
      fields: {'user_id': userId},
    );
    final map = (data as Map).cast<String, dynamic>();
    return PalmCountResult(
      count: (map['palm_count'] as num?)?.toInt() ?? 0,
      annotatedImage: map['annotated_image'] as String?,
    );
  }
}
