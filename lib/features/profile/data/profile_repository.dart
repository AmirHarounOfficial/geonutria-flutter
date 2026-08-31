import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/network/api_client.dart';
import 'profile_models.dart';

class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  int? get currentUserId => _api.userId;

  // --- Profile Operations ---
  Future<UserProfile> getProfile(int userId) async {
    if (userId <= 0) {
      throw const AppException('User ID is missing or invalid. Please login again.');
    }
    final data = await _api.get('/profile/', query: {'user_id': userId});
    if (data is Map) {
      return UserProfile.fromJson(data.cast<String, dynamic>());
    }
    throw const AppException('Invalid response format from profile API');
  }

  Future<List<TeamMember>> getTeam(int userId) async {
    if (userId <= 0) return [];
    try {
      final data = await _api.get('/profile/team', query: {'user_id': userId});
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => TeamMember.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> updateProfile(
    int userId, {
    String? name,
    String? mobile,
    int? age,
    String? sex,
  }) async {
    if (userId <= 0) throw const AppException('Invalid user ID');
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (mobile != null) payload['mobile'] = mobile;
    if (age != null) payload['age'] = age;
    if (sex != null) payload['sex'] = sex;

    await _api.put('/profile/update', query: {'user_id': userId}, body: payload);
  }

  Future<void> changePassword(
    int userId, {
    String? oldPassword,
    required String newPassword,
  }) async {
    if (userId <= 0) throw const AppException('Invalid user ID');
    final payload = <String, dynamic>{'new_password': newPassword};
    if (oldPassword != null && oldPassword.isNotEmpty) {
      payload['old_password'] = oldPassword;
    }
    await _api.post('/profile/password', query: {'user_id': userId}, body: payload);
  }

  Future<void> uploadPicture(int userId, XFile file) async {
    if (userId <= 0) throw const AppException('Invalid user ID');
    final bytes = await file.readAsBytes();
    await _api.upload(
      '/profile/picture',
      files: {'file': MultipartFile.fromBytes(bytes, filename: file.name)},
      fields: {'user_id': userId},
    );
  }

  Future<void> addTeamMember(
    int userId, {
    required String memberEmail,
    int? sharedCredits,
  }) async {
    if (userId <= 0) throw const AppException('Invalid user ID');
    final payload = <String, dynamic>{
      'member_email': memberEmail,
      'shared_credits': sharedCredits,
    };
    await _api.post('/profile/team/add', query: {'user_id': userId}, body: payload);
  }

  Future<void> removeTeamMember(int userId, int memberId) async {
    if (userId <= 0) throw const AppException('Invalid user ID');
    await _api.delete('/profile/team/remove/$memberId', query: {'user_id': userId});
  }

  // --- Assets Operations ---
  Future<List<Farm>> getFarms(int userId) async {
    if (userId <= 0) return [];
    try {
      final data = await _api.get('/assets/farms', query: {'user_id': userId});
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Farm.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<Crop>> getCrops(int farmId) async {
    try {
      final data = await _api.get('/assets/crops', query: {'farm_id': farmId});
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => Crop.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<TreeItem>> getTrees(int cropId) async {
    try {
      final data = await _api.get('/assets/trees', query: {'crop_id': cropId});
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => TreeItem.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<List<AssetMedia>> getMedia(String entityType, int entityId) async {
    try {
      final data = await _api.get(
        '/assets/media',
        query: {'entity_type': entityType, 'entity_id': entityId},
      );
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => AssetMedia.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> createFarm(int userId, Map<String, dynamic> farmData) async {
    await _api.post('/assets/farms', query: {'user_id': userId}, body: farmData);
  }

  Future<void> createCrop(Map<String, dynamic> cropData) async {
    await _api.post('/assets/crops', body: cropData);
  }

  Future<void> createTree(Map<String, dynamic> treeData) async {
    await _api.post('/assets/trees', body: treeData);
  }

  Future<void> deleteEntity(String type, int id) async {
    final path = '/assets/${type.toLowerCase()}s/$id';
    await _api.delete(path);
  }
}
