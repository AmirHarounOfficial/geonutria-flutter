import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geonutria_mobile/core/network/api_client.dart';
import 'package:geonutria_mobile/core/storage/secure_session.dart';
import 'package:geonutria_mobile/features/auth/bloc/auth_cubit.dart';
import 'package:geonutria_mobile/features/auth/data/auth_repository.dart';
import 'package:geonutria_mobile/features/crop_advisor/crop_advisor_cubit.dart';

class RecordingApi extends ApiClient {
  RecordingApi() : super(SecureSession());
  final requests = <String, Map>{};
  @override
  Stream<ChatToken> streamChatTokens(String path, {Object? body}) {
    requests[path] = body as Map;
    return Stream.value(const ChatToken.content('Clay'));
  }
}

class TestAuth extends AuthCubit {
  TestAuth(ApiClient api)
    : super(AuthRepository(api, SecureSession()), SecureSession());
  @override
  AuthState get state => const AuthState(userId: 7, aiCredits: 100);
  @override
  void onCreditsSpent([int amount = 5]) {}
}

void main() {
  for (final lang in ['en', 'ar']) {
    test('Soil and crop AI requests explicitly preserve $lang', () async {
      final api = RecordingApi();
      final auth = TestAuth(api);
      final cubit = CropAdvisorCubit(api, auth);
      await cubit.classifySoil(
        XFile.fromData(Uint8List.fromList([1, 2]), name: 'soil.jpg'),
        lang: lang,
      );
      await cubit.recommend(
        n: 10,
        p: 20,
        k: 30,
        temperature: 25,
        humidity: 50,
        ph: 7,
        rainfall: 100,
        soilType: 'Clay',
        lang: lang,
      );
      expect(api.requests['/classify-soil']!['lang'], lang);
      expect(api.requests['/recommend-crops']!['lang'], lang);
      expect(api.requests['/recommend-crops']!['user_id'], 7);
      await cubit.close();
      await auth.close();
    });
  }
}
