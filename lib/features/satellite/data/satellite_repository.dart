import '../../../core/network/api_client.dart';
import 'satellite_models.dart';

/// Wraps `POST /satellite-analysis` (costs 5 credits). Accepts either a point
/// (lat/lon + radius) or a polygon (list of [lat, lon] pairs).
class SatelliteRepository {
  SatelliteRepository(this._api);

  final ApiClient _api;

  Future<SatelliteResult> analyze({
    required int userId,
    double? lat,
    double? lon,
    double radiusKm = 1.0,
    required String startDate, // YYYY-MM-DD
    required String endDate,
    int compareValue = 3,
    String compareUnit = 'months',
    List<List<double>>? polygonCoords,
    int maxCloudCover = 10,
  }) async {
    final data = await _api.post('/satellite-analysis', body: {
      'lat': lat,
      'lon': lon,
      'radius_km': radiusKm,
      'start_date': startDate,
      'end_date': endDate,
      'compare_value': compareValue,
      'compare_unit': compareUnit,
      'polygon_coords': polygonCoords,
      'max_cloud_cover': maxCloudCover,
      'user_id': userId,
    });
    final map = (data as Map).cast<String, dynamic>();
    if (map['status'] == 'error') {
      throw Exception(map['message'] ?? 'Satellite analysis failed');
    }
    return SatelliteResult.fromJson(map);
  }
}
