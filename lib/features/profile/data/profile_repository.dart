import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/password.dart';
import 'profile_models.dart';

/// Wraps the `/profile` router (prefixed). `user_id` travels as a query param.
class ProfileRepository {
  ProfileRepository(this._api);

  final ApiClient _api;

  Future<UserProfile> getProfile() async {
    final data = await _api.get('/profile/', query: _api.authQuery());
    return UserProfile.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<void> updateProfile({
    String? name,
    String? mobile,
    int? age,
    String? sex,
  }) async {
    await _api.put('/profile/update', query: _api.authQuery(), body: {
      if (name != null) 'name': name,
      if (mobile != null) 'mobile': mobile,
      if (age != null) 'age': age,
      if (sex != null) 'sex': sex,
    });
  }

  Future<void> changePassword({String? oldPassword, required String newPassword}) async {
    await _api.post('/profile/password', query: _api.authQuery(), body: {
      if (oldPassword != null) 'old_password': bcryptSafePassword(oldPassword),
      'new_password': bcryptSafePassword(newPassword),
    });
  }

  Future<String> uploadPicture(int userId, XFile file) async {
    final bytes = await file.readAsBytes();
    final data = await _api.upload(
      '/profile/picture',
      files: {'file': MultipartFile.fromBytes(bytes, filename: file.name)},
      fields: {'user_id': userId},
    );
    return (data as Map)['picture_url']?.toString() ?? '';
  }

  Future<List<TeamMember>> getTeam() async {
    final data = await _api.get('/profile/team', query: _api.authQuery());
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => TeamMember.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  Future<void> addTeamMember(String email, {int? sharedCredits}) async {
    await _api.post('/profile/team/add', query: _api.authQuery(), body: {
      'member_email': email,
      if (sharedCredits != null) 'shared_credits': sharedCredits,
    });
  }

  Future<void> removeTeamMember(int memberUserId) async {
    await _api.delete('/profile/team/remove/$memberUserId', query: _api.authQuery());
  }
}
