import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonutria_mobile/core/localization/app_localizations.dart';
import 'package:geonutria_mobile/core/network/api_client.dart';
import 'package:geonutria_mobile/core/storage/secure_session.dart';
import 'package:geonutria_mobile/features/auth/bloc/auth_cubit.dart';
import 'package:geonutria_mobile/features/auth/data/auth_repository.dart';
import 'package:geonutria_mobile/features/crop_advisor/crop_advisor_screen.dart';
import 'package:geonutria_mobile/features/yield_predict/yield_screen.dart';
import 'package:geonutria_mobile/features/billing/billing_screen.dart';
import 'package:geonutria_mobile/features/report/report_screen.dart';

void main() {
  for (final lang in ['en', 'ar']) {
    for (final entry in <String, Widget>{
      'crop': const CropAdvisorScreen(),
      'yield': const YieldScreen(),
      'billing': const BillingScreen(),
      'report': const ReportScreen(),
    }.entries) {
      testWidgets('${entry.key} fits a phone in $lang', (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = SecureSession();
        final api = ApiClient(session);
        final auth = AuthCubit(AuthRepository(api, session), session);
        addTearDown(auth.close);
        await tester.pumpWidget(
          RepositoryProvider.value(
            value: api,
            child: BlocProvider.value(
              value: auth,
              child: MaterialApp(
                locale: Locale(lang),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: Scaffold(body: entry.value),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final scroll = find.byType(Scrollable).first;
        await tester.drag(scroll, const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
