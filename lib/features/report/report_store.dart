import 'package:flutter/foundation.dart';

/// In-memory results actually obtained in this session, using ReportRequest v2.
/// Export never invents readings or launches additional paid analyses.
class ReportStore extends ChangeNotifier {
  int? _userId;
  String? _deviceId;
  int? get selectedDeviceId => int.tryParse(_deviceId ?? '');
  final Map<String, dynamic> _data = {};
  final Map<String, Map> _devices = {};
  final Map<String, String> _languages = {};
  final Map<String, Map<String, dynamic>> _runs = {};

  static const sections = <String, String>{
    'iot': 'IoT sensors',
    'weather': 'Live weather',
    'history': 'Historical readings',
    'device_map': 'Device satellite imagery',
    'leaf': 'Leaf diagnosis',
    'soil': 'Soil analysis',
    'crop': 'Crop recommendation',
    'yield': 'Yield prediction',
    'advanced_ai': 'Advanced AI',
    'accounting': 'Farm accounting',
    'control': 'Control & Automation',
    'consultant': 'AI consultant',
    'satellite': 'Satellite',
  };
  static const _options = <String, String>{
    'iot': 'include_iot',
    'weather': 'include_weather',
    'history': 'include_history',
    'device_map': 'include_device_map',
    'leaf': 'include_leaf_ai',
    'soil': 'include_soil_ai',
    'crop': 'include_crop_ai',
    'yield': 'include_yield_ai',
    'advanced_ai': 'include_advanced_ai',
    'accounting': 'include_accounting',
    'control': 'include_control',
    'consultant': 'include_consultant',
    'satellite': 'include_satellite',
  };

  void useUser(int? id) {
    if (_userId == id) return;
    _userId = id;
    _deviceId = null;
    _data.clear();
    _devices.clear();
    _runs.clear();
    _languages.clear();
    notifyListeners();
  }

  void selectDevice(int id) {
    if (_deviceId == '$id') return;
    _deviceId = '$id';
    final device = _devices['$id'];
    final lat = double.tryParse('${device?['latitude']}');
    final lon = double.tryParse('${device?['longitude']}');
    if (device != null &&
        lat != null &&
        lon != null &&
        lat.isFinite &&
        lon.isFinite &&
        lat.abs() <= 90 &&
        lon.abs() <= 180) {
      final previous = _data['device_imagery'] as List? ?? [];
      record('device_map', {
        'device_imagery': [
          {
            'device_id': id,
            'device_name': device['device_name'],
            'installed_location': device['installed_location'],
            'latitude': lat,
            'longitude': lon,
            'image_source': 'esri-world-imagery',
            'zoom': 17,
            'attribution': 'Imagery © Esri, Maxar, Earthstar Geographics',
          },
          ...previous.where((d) => d['device_id'] != id),
        ].take(4).toList(),
      });
    }
    for (final section in ['iot', 'weather', 'history']) {
      _runs.remove(section);
    }
    for (final key in [
      'iot_data',
      'iot_device',
      'iot_ai_status',
      'iot_ai_confidence',
      'iot_rag_text',
      'weather_data',
      'iot_history',
    ]) {
      _data.remove(key);
    }
    notifyListeners();
  }

  Set<String> available(String lang) => _runs.keys
      .where((key) => _languages[key] == null || _languages[key] == lang)
      .toSet();

  void record(String section, Map<String, dynamic> fields, {String? lang}) {
    if (_userId == null) return;
    _data.addAll(fields);
    if (lang != null) _languages[section] = lang;
    _runs[section] = {
      'ran': true,
      'ok': true,
      'ran_at': DateTime.now().toUtc().toIso8601String(),
    };
    notifyListeners();
  }

  void capture(
    String path,
    dynamic response, {
    dynamic body,
    Map<String, dynamic> query = const {},
  }) {
    if (response is Map && response['status'] == 'error') return;
    if (path == '/devices' && response is List) {
      _devices.clear();
      for (final d in response.whereType<Map>()) {
        _devices['${d['id']}'] = d;
      }
    }
    if (path == '/iot-status' &&
        response is Map &&
        '${query['device_id']}' == _deviceId) {
      final sensors = sanitizeSensors(response['sensors']);
      if (sensors.isEmpty ||
          response['ai_diagnosis']?['status'] == 'No Live Data')
        return;
      final diagnosis = response['ai_diagnosis'];
      record('iot', {
        'iot_data': sensors,
        'iot_sensors_available': sensors.keys.toList(),
        'iot_device': {'id': query['device_id']},
        'iot_ai_status': diagnosis?['status'] ?? 'Unknown',
        'iot_ai_confidence': diagnosis?['probabilities'] is Map
            ? (diagnosis['probabilities'] as Map).values
                      .whereType<num>()
                      .fold<num>(0, (a, b) => a > b ? a : b) *
                  100
            : 0,
      });
    } else if (path.startsWith('/iot-history/') &&
        response is Map &&
        path.split('/').last == _deviceId) {
      final points = response['data'];
      if (points is List && points.isNotEmpty)
        record('history', {
          'iot_history': historyBlock(
            points,
            query['interval']?.toString() ?? 'Live',
          ),
        });
    } else if (path.startsWith('/weather-charts/') &&
        response is Map &&
        path.split('/').last == _deviceId) {
      final rows = response['data'];
      if (rows is List) {
        final observed = rows
            .whereType<Map>()
            .where((r) => r['is_forecast'] != true)
            .toList();
        if (observed.isNotEmpty) {
          final latest = observed.last;
          record('weather', {
            'weather_data': {
              ...latest,
              'relative_humidity_pct': latest['relative_humidity'],
              'captured_at': latest['label'],
            },
          });
        }
      }
    } else if ((path == '/diagnose-leaf' || path == '/diagnose-palm-disease') &&
        response is Map) {
      record('leaf', {
        'leaf_diagnosis': {
          ...Map<String, dynamic>.from(response),
          'confidence':
              response['diagnosis_confidence'] ?? response['confidence'],
        },
      });
    } else if (path == '/satellite-analysis' && response is Map) {
      final meta = response['meta'] as Map? ?? {};
      record('satellite', {
        'satellite_data': {
          'rgb': response['rgb'],
          ...Map<String, dynamic>.from(response['indices'] as Map? ?? {}),
        },
        'sat_date_current': meta['date_current'],
        'sat_date_past': meta['date_past'],
        'satellite_area': meta['area_km2'],
      });
    } else if (path == '/control/actuators' || path == '/control/schedules') {
      if (response is List) {
        final previous = Map<String, dynamic>.from(
          _data['control_automation'] ?? {},
        );
        previous[path.split('/').last] = response;
        record('control', {'control_automation': previous});
      }
    }
  }

  void captureStream(String path, Map body, String text) {
    if (text.trim().isEmpty) return;
    final lang = body['lang']?.toString() ?? 'en';
    switch (path) {
      case '/classify-soil':
        record('soil', {'soil_ai_text': text}, lang: lang);
      case '/recommend-crops':
        record('crop', {
          'crop_inputs': _inputs(body),
          'crop_ai_text': text,
          'crop_recommendations': <dynamic>[],
        }, lang: lang);
      case '/predict-yield':
        record('yield', {
          'yield_inputs': _inputs(body),
          'yield_ai_text': text,
          'yield_prediction': <String, dynamic>{},
        }, lang: lang);
      case '/v1/rag-diagnosis':
        _data['iot_rag_text'] = text;
        _languages['iot'] = lang;
        notifyListeners();
      case '/accounting/ai-advisor':
        _data['accounting_ai_text'] = text;
        _languages['accounting'] = lang;
        notifyListeners();
      case '/control/suggest-automation/stream':
        _data['control_ai_text'] = text;
        _languages['control'] = lang;
        notifyListeners();
      case '/v1/openrouter-chat':
        final contents = body['messages'] ?? body['contents'];
        final turns = <Map<String, dynamic>>[];
        String question = '';
        if (contents is List) {
          for (final turn in contents.whereType<Map>()) {
            if (turn['content'] is String && turn['role'] != 'system') {
              if (turn['role'] == 'user') {
                question = turn['content'] as String;
              } else if (turn['role'] == 'assistant') {
                turns.add({'question': question, 'answer': turn['content']});
                question = '';
              }
            }
          }
        }
        turns.add({'question': question, 'answer': text});
        record('advanced_ai', {
          'advanced_ai': {
            'turns': turns
                .skip(turns.length > 6 ? turns.length - 6 : 0)
                .toList(),
          },
        }, lang: lang);
    }
  }

  static Map<String, dynamic> _inputs(Map body) => {
    for (final e in body.entries)
      if (!['user_id', 'lang', 'stream', 'image_base64'].contains(e.key))
        '${e.key}': e.value,
  };

  Map<String, dynamic> payload({
    required int userId,
    required String lang,
    required String farmName,
    required String farmerName,
    required Set<String> selected,
  }) {
    if (_userId != userId) throw StateError('Report session changed');
    final enabled = selected.intersection(available(lang));
    return {
      ..._data,
      for (final key in [
        'accounting_revenue_breakdown',
        'accounting_expense_breakdown',
      ])
        if (_data[key] is List)
          key: [
            for (final entry in (_data[key] as List).take(8))
              {...entry as Map, 'name': entry['name_$lang']},
          ],
      'schema_version': 2,
      'user_id': userId,
      'farm_name': farmName,
      'farmer_name': farmerName,
      'options': {
        for (final e in _options.entries) e.value: enabled.contains(e.key),
        'language': lang,
      },
      'module_runs': {for (final key in enabled) key: _runs[key]},
    };
  }

  static Map<String, dynamic> historyBlock(List raw, String interval) {
    final rows = raw.whereType<Map>().take(24).toList().reversed.toList();
    const units = {
      'moisture': '%',
      'soil_temp': '°C',
      'temperature': '°C',
      'humidity': '%',
      'ph': '',
      'nitrogen': 'mg/kg',
      'phosphorus': 'mg/kg',
      'potassium': 'mg/kg',
    };
    final metrics = <Map<String, dynamic>>[];
    for (final e in units.entries) {
      final values = rows
          .map((r) => double.tryParse('${r[e.key]}'))
          .whereType<double>()
          .where((v) => v.isFinite)
          .toList();
      if (values.isEmpty) continue;
      final diff = values.last - values.first;
      metrics.add({
        'key': e.key,
        'unit': e.value,
        'min': values.reduce((a, b) => a < b ? a : b),
        'max': values.reduce((a, b) => a > b ? a : b),
        'avg': values.reduce((a, b) => a + b) / values.length,
        'latest': values.last,
        'trend': diff.abs() < .01
            ? 'stable'
            : diff > 0
            ? 'rising'
            : 'falling',
      });
    }
    return {
      'interval': interval,
      'metrics': metrics,
      'point_count': rows.length,
      'truncated': raw.length > 24,
      if (rows.isNotEmpty) 'from': rows.first['timestamp'],
      if (rows.isNotEmpty) 'to': rows.last['timestamp'],
      'points': [
        for (final row in rows)
          {
            't': row['timestamp'],
            for (final key in units.keys)
              if (row[key] != null) key: row[key],
          },
      ],
    };
  }

  static Map<String, double> sanitizeSensors(dynamic raw) {
    if (raw is! Map) return {};
    const dead = {'Light_Intensity', 'Chlorophyll_Content', 'Chlorophyll'};
    const absentZero = {
      'Soil_pH',
      'Soil_Salinity',
      'Salinity',
      'TDS',
      'Epsilon',
      'Ambient_Temperature',
      'Humidity',
    };
    final result = <String, double>{};
    for (final e in raw.entries) {
      final key = e.key == 'Electrochemical_Signal'
          ? 'Soil_Salinity'
          : '${e.key}';
      final value = double.tryParse('${e.value}');
      if (dead.contains(key) ||
          value == null ||
          !value.isFinite ||
          (value == 0 && absentZero.contains(key)))
        continue;
      result[key] = value;
    }
    return result;
  }
}
