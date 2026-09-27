import 'package:flutter_test/flutter_test.dart';
import 'package:geonutria_mobile/core/error/app_exception.dart';
import 'package:geonutria_mobile/core/network/api_client.dart';
import 'package:geonutria_mobile/core/storage/secure_session.dart';
import 'package:geonutria_mobile/features/profile/bloc/profile_cubit.dart';
import 'package:geonutria_mobile/features/profile/data/profile_repository.dart';
import 'package:geonutria_mobile/features/profile/data/phone_number.dart';
import 'ai_language_test.dart' show TestAuth;

class PasswordApi extends ApiClient {
  PasswordApi() : super(SecureSession());
  bool fail = false;
  Map? payload;
  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) async {
    expect(path, '/profile/password');
    expect(query, {'user_id': 7});
    payload = body as Map;
    if (fail) throw const AppException('Incorrect old password');
    return {'message': 'Password updated successfully'};
  }
}

void main() {
  test(
    'Phone serialization separates plus prefix and normalizes Arabic digits',
    () {
      expect(profilePhone('20', '٠١٠١٢٣٤٥٦٧٨'), '201012345678');
      expect(profilePhone('+20', '1012345678'), '201012345678');
      expect(profilePhone('966', '0501234567'), '966501234567');
      expect(profilePhone('39', '0612345678'), '390612345678');
      expect(profilePhone('20', 'abc123'), isNull);
      expect(profilePhone('20', '123'), isNull);
      expect(profilePhone('20', '1999999999'), isNull);
      expect(profilePhone('971', '1234567890123456'), isNull);
      expect(profilePhone('20', ''), '');
    },
  );
  test(
    'Existing local and international phone numbers hydrate without duplication',
    () {
      expect(splitProfilePhone('+20 1012345678'), ('20', '1012345678'));
      expect(splitProfilePhone('201012345678'), ('20', '1012345678'));
      expect(splitProfilePhone('00966501234567'), ('966', '501234567'));
      expect(splitProfilePhone('01012345678'), ('20', '01012345678'));
      expect(splitProfilePhone('1012345678'), ('20', '1012345678'));
      expect(splitProfilePhone('+61 412345678'), ('', '61412345678'));
    },
  );
  test(
    'Password success and repeated failures return explicit outcomes',
    () async {
      final api = PasswordApi();
      final auth = TestAuth(api);
      final cubit = ProfileCubit(ProfileRepository(api), auth);
      final events = <ProfileState>[];
      final subscription = cubit.stream.listen(events.add);
      expect(
        await cubit.changePassword(
          oldPassword: ' old password ',
          newPassword: 'new password',
        ),
        isTrue,
      );
      expect(api.payload!['old_password'], ' old password ');
      expect(cubit.state.message, 'Password updated successfully ✅');
      api.fail = true;
      expect(
        await cubit.changePassword(
          oldPassword: 'wrong',
          newPassword: 'new password',
        ),
        isFalse,
      );
      expect(cubit.state.error, 'Incorrect old password');
      expect(
        await cubit.changePassword(
          oldPassword: 'wrong',
          newPassword: 'new password',
        ),
        isFalse,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        events.where((s) => s.error == 'Incorrect old password').length,
        2,
      );
      await subscription.cancel();
      await cubit.close();
      await auth.close();
    },
  );
}
