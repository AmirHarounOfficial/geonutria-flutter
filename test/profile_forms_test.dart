import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonutria_mobile/core/localization/app_localizations.dart';
import 'package:geonutria_mobile/core/network/api_client.dart';
import 'package:geonutria_mobile/core/storage/secure_session.dart';
import 'package:geonutria_mobile/core/error/app_exception.dart';
import 'package:geonutria_mobile/features/auth/bloc/auth_cubit.dart';
import 'package:geonutria_mobile/features/profile/ui/profile_screen.dart';
import 'package:geonutria_mobile/features/farm_context/farm_hierarchy_cubit.dart';
import 'package:geonutria_mobile/features/farm_context/global_context_bar.dart';
import 'package:geonutria_mobile/features/crop_advisor/crop_advisor_screen.dart';
import 'package:geonutria_mobile/features/deep_analysis/data/analysis_context.dart';
import 'ai_language_test.dart' show TestAuth;

class FormApi extends ApiClient {
  FormApi() : super(SecureSession());
  Completer<dynamic>? passwordResult;
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async =>
      path == '/profile/'
      ? {
          'id': 7,
          'name': 'Tester',
          'email': 'test@example.test',
          'mobile': '201012345678',
          'has_password': true,
        }
      : [];
  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) {
    expect(path, '/profile/password');
    passwordResult = Completer<dynamic>();
    return passwordResult!.future;
  }
}

class TestHierarchy extends FarmHierarchyCubit {
  TestHierarchy(super.api, super.auth);
  @override
  FarmHierarchyState get state => const FarmHierarchyState(
    farms: [
      FarmItem(id: 1, name: 'Nile Farm'),
      FarmItem(id: 2, name: 'مزرعة النور'),
    ],
  );
}

Widget app(Widget child, String lang, ApiClient api, AuthCubit auth) =>
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
          home: Scaffold(body: TickerMode(enabled: false, child: child)),
        ),
      ),
    );

void main() {
  for (final lang in ['en', 'ar']) {
    testWidgets(
      'Crop Advisor location offers farms and saves typed input in $lang',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = FormApi();
        final auth = TestAuth(api);
        final hierarchy = TestHierarchy(api, auth);
        addTearDown(auth.close);
        addTearDown(hierarchy.close);
        final labels = AppLocalizations(Locale(lang));
        await tester.pumpWidget(
          app(
            BlocProvider<FarmHierarchyCubit>.value(
              value: hierarchy,
              child: const CropAdvisorScreen(),
            ),
            lang,
            api,
            auth,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(labels.label('Edit Context')));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nile Farm').last);
        await tester.pumpAndSettle();
        final field = find.widgetWithText(
          TextField,
          labels.label('Location / Region'),
        );
        expect(tester.widget<TextField>(field).controller!.text, 'Nile Farm');
        await tester.enterText(field, 'موقع جديد');
        await tester.pumpAndSettle();
        expect(tester.widget<TextField>(field).controller!.text, 'موقع جديد');
        await tester.tap(
          find.widgetWithText(FilledButton, labels.label('Save Context')),
        );
        await tester.pumpAndSettle();
        expect((await AnalysisContextStore().read()).location, 'موقع جديد');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('Main context retains geographic region dropdown in $lang', (
      tester,
    ) async {
      FlutterSecureStorage.setMockInitialValues({});
      final api = FormApi();
      final auth = TestAuth(api);
      final hierarchy = TestHierarchy(api, auth);
      addTearDown(auth.close);
      addTearDown(hierarchy.close);
      final labels = AppLocalizations(Locale(lang));
      await tester.pumpWidget(
        app(
          BlocProvider<FarmHierarchyCubit>.value(
            value: hierarchy,
            child: const SingleChildScrollView(child: GlobalContextBar()),
          ),
          lang,
          api,
          auth,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(labels.tr('fc_expand')));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextField, labels.tr('fc_location')),
        findsNothing,
      );
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      final dropdowns = tester.widgetList<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(
        dropdowns.any((d) => d.items!.any((item) => item.value == 'Cairo')),
        isTrue,
      );
    });

    testWidgets(
      'Password form shows failure, preserves input, then shows success in $lang',
      (tester) async {
        FlutterSecureStorage.setMockInitialValues({});
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final api = FormApi();
        final auth = TestAuth(api);
        addTearDown(auth.close);
        final labels = AppLocalizations(Locale(lang));
        await tester.pumpWidget(app(const ProfileScreen(), lang, api, auth));
        await tester.pumpAndSettle();
        final button = find.widgetWithText(
          OutlinedButton,
          labels.label('Update Password'),
        );
        await tester.scrollUntilVisible(
          button,
          250,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.pumpAndSettle();
        final old = find.widgetWithText(
          TextField,
          labels.label('Old Password'),
        );
        final next = find.widgetWithText(
          TextField,
          labels.label('New Password'),
        );
        await tester.enterText(old, 'current password');
        await tester.enterText(next, 'new password');
        await tester.tap(button);
        await tester.pump();
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        api.passwordResult!.completeError(
          const AppException('Incorrect old password'),
        );
        await tester.pumpAndSettle();
        expect(find.text(labels.label('Incorrect old password')), findsWidgets);
        expect(tester.widget<TextField>(next).controller!.text, 'new password');
        await tester.tap(button);
        await tester.pump();
        api.passwordResult!.complete({'message': 'ok'});
        await tester.pumpAndSettle();
        expect(
          find.text(labels.label('Password updated successfully ✅')),
          findsWidgets,
        );
        expect(tester.widget<TextField>(next).controller!.text, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
