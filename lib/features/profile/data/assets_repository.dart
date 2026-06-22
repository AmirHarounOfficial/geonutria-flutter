import '../../../core/network/api_client.dart';

class Farm {
  const Farm({
    required this.id,
    required this.name,
    this.address,
    this.totalArea,
    this.latitude,
    this.longitude,
  });
  final int id;
  final String name;
  final String? address;
  final double? totalArea;
  final double? latitude;
  final double? longitude;

  factory Farm.fromJson(Map<String, dynamic> j) => Farm(
        id: (j['id'] as num).toInt(),
        name: (j['farm_name'] ?? '').toString(),
        address: j['address']?.toString(),
        totalArea: (j['total_area'] as num?)?.toDouble(),
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
      );
}

class Crop {
  const Crop({
    required this.id,
    required this.name,
    this.category,
    this.plantedArea,
    this.healthStatus,
  });
  final int id;
  final String name;
  final String? category;
  final double? plantedArea;
  final String? healthStatus;

  factory Crop.fromJson(Map<String, dynamic> j) => Crop(
        id: (j['id'] as num).toInt(),
        name: (j['crop_name'] ?? '').toString(),
        category: j['crop_category']?.toString(),
        plantedArea: (j['planted_area'] as num?)?.toDouble(),
        healthStatus: j['health_status']?.toString(),
      );
}

class Tree {
  const Tree({
    required this.id,
    required this.name,
    this.code,
    this.healthStatus,
  });
  final int id;
  final String name;
  final String? code;
  final String? healthStatus;

  factory Tree.fromJson(Map<String, dynamic> j) => Tree(
        id: (j['id'] as num).toInt(),
        name: (j['tree_name'] ?? '').toString(),
        code: j['tree_code']?.toString(),
        healthStatus: j['health_status']?.toString(),
      );
}

/// Wraps the `/assets` router (farm → crop → tree hierarchy + media).
class AssetsRepository {
  AssetsRepository(this._api);

  final ApiClient _api;

  // --- Farms ---
  Future<List<Farm>> getFarms() async {
    final data = await _api.get('/assets/farms', query: _api.authQuery());
    return _list(data, Farm.fromJson);
  }

  Future<void> createFarm({
    required String name,
    required String address,
    required double totalArea,
    double? latitude,
    double? longitude,
  }) =>
      _api.post('/assets/farms', query: _api.authQuery(), body: {
        'farm_name': name,
        'address': address,
        'total_area': totalArea,
        'latitude': latitude,
        'longitude': longitude,
      });

  Future<void> deleteFarm(int id) => _api.delete('/assets/farms/$id');

  // --- Crops ---
  Future<List<Crop>> getCrops(int farmId) async {
    final data = await _api.get('/assets/crops', query: {'farm_id': farmId});
    return _list(data, Crop.fromJson);
  }

  Future<void> createCrop({
    required int farmId,
    required String category,
    required String name,
    required double plantedArea,
  }) =>
      _api.post('/assets/crops', body: {
        'farm_id': farmId,
        'crop_category': category,
        'crop_name': name,
        'planted_area': plantedArea,
      });

  Future<void> deleteCrop(int id) => _api.delete('/assets/crops/$id');

  // --- Trees ---
  Future<List<Tree>> getTrees(int cropId) async {
    final data = await _api.get('/assets/trees', query: {'crop_id': cropId});
    return _list(data, Tree.fromJson);
  }

  Future<void> createTree({
    required int cropId,
    required String name,
    required String code,
  }) =>
      _api.post('/assets/trees', body: {
        'crop_id': cropId,
        'tree_name': name,
        'tree_code': code,
      });

  Future<void> deleteTree(int id) => _api.delete('/assets/trees/$id');

  // --- Media ---
  Future<List<String>> getMedia(String entityType, int entityId) async {
    final data = await _api.get('/assets/media',
        query: {'entity_type': entityType, 'entity_id': entityId});
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => '${e['file_url']}')
          .toList();
    }
    return [];
  }

  List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }
}
