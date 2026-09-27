import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geonutria_mobile/core/localization/app_localizations.dart';
import 'package:geonutria_mobile/core/localization/app_strings.dart';
import 'package:geonutria_mobile/core/localization/ui_labels.dart';
import 'package:geonutria_mobile/features/dashboard/data/iot_models.dart';
import 'package:geonutria_mobile/features/dashboard/ui/widgets/diagnosis_card.dart';

void main() {
  test('Every literal display label has an Arabic translation', () {
    final ar = AppLocalizations(const Locale('ar'));
    final calls = RegExp(r"\.ui\(\s*'([^'$]+)'\s*[,)]");
    final missing = <String>{};
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final call in calls.allMatches(file.readAsStringSync())) {
        final label = call[1]!;
        if (RegExp('[A-Za-z]').hasMatch(label) && ar.label(label) == label) {
          missing.add(label);
        }
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });
  test('Both locales define every literal translation key used by the app', () {
    expect(
      AppStrings.values['ar']!.keys.toSet(),
      AppStrings.values['en']!.keys.toSet(),
    );
    final calls = RegExp(r"\.tr\('([^'$]+)'\)");
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') ||
          file.path.contains('app_localizations'))
        continue;
      for (final call in calls.allMatches(file.readAsStringSync())) {
        expect(AppStrings.values['en'], contains(call[1]), reason: file.path);
        expect(AppStrings.values['ar'], contains(call[1]), reason: file.path);
      }
    }
  });

  test('Display catalog has actual Arabic translations', () {
    for (final entry in arabicUiLabels.entries) {
      expect(entry.value, isNot(entry.key), reason: entry.key);
      expect(
        RegExp(r'[\u0600-\u06ff]').hasMatch(entry.value),
        isTrue,
        reason: entry.key,
      );
    }
    expect(
      AppLocalizations(const Locale('ar')).errorText('Unknown server failure'),
      AppStrings.values['ar']!['error_generic'],
    );
    expect(AppLocalizations(const Locale('en')).label('Healthy'), 'Healthy');
  });

  for (final lang in ['en', 'ar']) {
    testWidgets('Diagnosis uses $lang labels and direction at phone width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: Locale(lang),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const Scaffold(
            body: DiagnosisCard(
              diagnosis: Diagnosis(
                status: 'Healthy',
                probabilities: {'Healthy': .7, 'Moderate': .2, 'High': .1},
                features: {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(lang == 'ar' ? 'تشخيص صحة النبات' : 'AI Health Diagnosis'),
        findsOneWidget,
      );
      expect(
        find.text(lang == 'ar' ? 'High Stress' : 'إجهاد شديد'),
        findsNothing,
      );
      expect(
        Directionality.of(tester.element(find.byType(DiagnosisCard))),
        lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
