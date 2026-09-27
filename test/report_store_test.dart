import 'package:flutter_test/flutter_test.dart';
import 'package:geonutria_mobile/features/report/report_store.dart';

void main() {
  test('Device imagery uses real visited locations and clears on logout', () {
    final store = ReportStore()..useUser(7);
    store.capture('/devices', [
      {'id': 2, 'device_name': 'Soil', 'latitude': 30.0, 'longitude': 31.0},
      {'id': 3, 'device_name': 'No coordinates'},
    ]);
    store.selectDevice(2);
    store.selectDevice(3);
    final data = store.payload(
      userId: 7,
      lang: 'en',
      farmName: '',
      farmerName: '',
      selected: {'device_map'},
    );
    expect(data['device_imagery'], hasLength(1));
    expect(data['device_imagery'][0]['device_id'], 2);
    expect(data['options']['include_device_map'], isTrue);
    expect(data['options']['include_leaf_ai'], isFalse);
    store.useUser(null);
    expect(store.available('en'), isEmpty);
  });
  test('Control advice is captured from the deployed stream endpoint', () {
    final store = ReportStore()..useUser(7);
    store.capture('/control/actuators', <dynamic>[]);
    store.captureStream('/control/suggest-automation/stream', {
      'lang': 'ar',
    }, 'نصيحة الري');
    final payload = store.payload(
      userId: 7,
      lang: 'ar',
      farmName: '',
      farmerName: '',
      selected: {'control'},
    );
    expect(payload['control_ai_text'], 'نصيحة الري');
    expect(payload['options']['include_control'], isTrue);
    expect(store.available('en'), isNot(contains('control')));
  });
  test(
    'History export uses chronological v2 points and calculated metrics',
    () {
      final block = ReportStore.historyBlock([
        {'timestamp': '2026-09-27 12:00', 'moisture': 40},
        {'timestamp': '2026-09-27 11:00', 'moisture': 20},
      ], 'Hours');
      expect((block['points'] as List).first['t'], '2026-09-27 11:00');
      expect((block['metrics'] as List).single['avg'], 30);
      expect((block['metrics'] as List).single['trend'], 'rising');
    },
  );
  test('Advanced AI export pairs questions with answers', () {
    final store = ReportStore()..useUser(7);
    store.captureStream('/v1/openrouter-chat', {
      'lang': 'en',
      'messages': [
        {'role': 'user', 'content': 'How much water?'},
      ],
    }, 'Measure soil moisture first.');
    final payload = store.payload(
      userId: 7,
      lang: 'en',
      farmName: '',
      farmerName: '',
      selected: {'advanced_ai'},
    );
    expect(payload['advanced_ai']['turns'], [
      {'question': 'How much water?', 'answer': 'Measure soil moisture first.'},
    ]);
  });
  test('Reports have no synthetic results and require a matching account', () {
    final store = ReportStore()..useUser(7);
    final payload = store.payload(
      userId: 7,
      lang: 'ar',
      farmName: '',
      farmerName: '',
      selected: {'iot', 'crop', 'yield'},
    );
    expect(payload, isNot(contains('iot_data')));
    expect(payload, isNot(contains('crop_recommendations')));
    expect((payload['options'] as Map)['include_iot'], isFalse);
    expect(payload['user_id'], 7);
    expect(
      () => store.payload(
        userId: 1,
        lang: 'en',
        farmName: '',
        farmerName: '',
        selected: {},
      ),
      throwsStateError,
    );
  });
  test(
    'Missing probes are omitted, while real zero NPK/moisture are retained',
    () {
      final values = ReportStore.sanitizeSensors({
        'Light_Intensity': 100,
        'Soil_pH': 0,
        'Nitrogen_Level': 0,
        'Soil_Moisture': 0,
        'Humidity': 0,
        'Electrochemical_Signal': 12,
        'Potassium_Level': null,
        'TDS': double.nan,
      });
      expect(values, {
        'Nitrogen_Level': 0.0,
        'Soil_Moisture': 0.0,
        'Soil_Salinity': 12.0,
      });
    },
  );
  test('Changing device/account cannot export earlier readings', () {
    final store = ReportStore()
      ..useUser(7)
      ..selectDevice(2);
    store.capture(
      '/iot-status',
      {
        'sensors': {'Soil_Moisture': 40},
      },
      query: {'device_id': 2},
    );
    expect(store.available('en'), contains('iot'));
    store.selectDevice(3);
    store.capture(
      '/iot-status',
      {
        'sensors': {'Soil_Moisture': 40},
      },
      query: {'device_id': 2},
    );
    expect(store.available('en'), isEmpty);
    store.record('crop', {'crop_ai_text': 'Wheat'}, lang: 'en');
    expect(store.available('ar'), isEmpty);
    store.useUser(8);
    expect(store.available('en'), isEmpty);
  });
}
