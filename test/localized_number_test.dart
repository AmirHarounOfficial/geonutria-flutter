import 'package:flutter_test/flutter_test.dart';
import 'package:geonutria_mobile/core/localization/localized_number.dart';

void main() {
  test('Arabic, Persian, and English numbers share the same API value', () {
    expect(parseLocalizedDouble('١٬٢٣٤٫٥'), 1234.5);
    expect(parseLocalizedDouble('−٢٫٥'), -2.5);
    expect(parseLocalizedInt('۱۲۳'), 123);
    expect(parseLocalizedDouble('1234.5'), 1234.5);
    expect(parseLocalizedDouble('NaN'), isNull);
    expect(parseLocalizedDouble('Infinity'), isNull);
    expect(parseLocalizedDouble('١٢abc'), isNull);
  });
}
