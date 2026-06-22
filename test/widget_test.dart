import 'package:flutter_test/flutter_test.dart';

import 'package:geonutria_mobile/core/config/env.dart';

void main() {
  test('resolveMedia builds absolute static URLs', () {
    expect(
      Env.resolveMedia('/static/outputs/x.webp'),
      '${Env.staticBaseUrl}/static/outputs/x.webp',
    );
    expect(Env.resolveMedia('https://cdn/x.png'), 'https://cdn/x.png');
    expect(Env.resolveMedia(''), '');
  });
}
