import 'dart:convert';
import 'package:latlong2/latlong.dart';
import '../../../core/widgets/app_map.dart';
import '../../../core/widgets/map_location_picker.dart';
import '../../../core/localization/localized_number.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/status_views.dart';

/// Admin-only device inventory, backed by the existing dashboard endpoints.
class AdminInventory extends StatefulWidget {
  const AdminInventory({super.key, required this.actuators});
  final bool actuators;
  @override
  State<AdminInventory> createState() => _AdminInventoryState();
}

class _AdminInventoryState extends State<AdminInventory> {
  List<Map<String, dynamic>>? _items;
  String? _error;
  ApiClient get _api => context.read<ApiClient>();
  String get _path => widget.actuators ? '/admin/actuators' : '/admin/devices';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get(
        widget.actuators ? _path : '/devices',
        query: {widget.actuators ? 'admin_id' : 'user_id': _api.userId},
      );
      if (data is! List) throw StateError('Unexpected response');
      if (mounted)
        setState(() {
          _items = data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          _error = null;
        });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    final api = _api;
    final users = await api.get(
      '/admin/users',
      query: {'admin_id': api.userId},
    );
    if (!mounted || users is! List) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _InventoryEditor(
        api: api,
        item: item,
        actuators: widget.actuators,
        users: users.whereType<Map>().toList(),
      ),
    );
    if (changed == true) await _load();
  }

  Future<void> _delete(Map item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('delete')),
        content: Text('${ctx.ui('Delete device')} "${item['device_name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.tr('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.delete(
        '$_path/${item['id']}',
        query: {'admin_id': _api.userId},
      );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: FilledButton.icon(
          onPressed: () async {
            try {
              await _edit();
            } catch (e) {
              if (mounted) setState(() => _error = '$e');
            }
          },
          icon: const Icon(Icons.add),
          label: Text(context.tr('add')),
        ),
      ),
      if (_error != null) Text(context.errorText(_error!)),
      Expanded(
        child: _items == null
            ? (_error == null
                  ? const LoadingView()
                  : ErrorView(message: _error!, onRetry: _load))
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  children: [
                    if (!widget.actuators && _items!.isNotEmpty)
                      SizedBox(
                        height: 230,
                        child: AppMap(
                          center: LatLng(30.0444, 31.2357),
                          zoom: 5,
                          markers: [
                            for (final e in _items!)
                              if (double.tryParse('${e['latitude']}') != null &&
                                  double.tryParse('${e['longitude']}') != null)
                                LatLng(
                                  double.parse('${e['latitude']}'),
                                  double.parse('${e['longitude']}'),
                                ),
                          ],
                        ),
                      ),
                    for (final item in _items!)
                      ListTile(
                        title: Text('${item['device_name']}'),
                        subtitle: Text('${item['installed_location'] ?? ''}'),
                        onTap: () async {
                          try {
                            await _edit(item);
                          } catch (e) {
                            if (mounted) setState(() => _error = '$e');
                          }
                        },
                        trailing: IconButton(
                          tooltip: context.tr('delete'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(item),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    ],
  );
}

class _InventoryEditor extends StatefulWidget {
  const _InventoryEditor({
    required this.api,
    required this.item,
    required this.actuators,
    required this.users,
  });
  final ApiClient api;
  final Map<String, dynamic>? item;
  final bool actuators;
  final List<Map> users;
  @override
  State<_InventoryEditor> createState() => _InventoryEditorState();
}

class _InventoryEditorState extends State<_InventoryEditor> {
  final _form = GlobalKey<FormState>();
  final _fields = <String, TextEditingController>{};
  final _assigned = <int>{};
  String _type = 'Pump';
  bool _busy = false;
  String? _error;
  bool _testing = false;
  String? _mqttResult;
  static const labels = {
    'device_name': 'Device name',
    'installed_location': 'Location',
    'farm_id': 'Farm ID (optional)',
    'latitude': 'Latitude',
    'longitude': 'Longitude',
    'mqtt_topics': 'MQTT topics (one per line)',
    'mqtt_publish_topic': 'Command topic',
    'mqtt_subscribe_topic': 'State topic (optional)',
  };
  @override
  void initState() {
    super.initState();
    final item = widget.item ?? {};
    for (final key in labels.keys) {
      dynamic value = item[key];
      if (key == 'mqtt_topics') {
        if (value is String) {
          try {
            value = jsonDecode(value);
          } catch (_) {}
        }
        if (value is List) value = value.join('\n');
      }
      _fields[key] = TextEditingController(text: '${value ?? ''}');
    }
    _type = '${item['device_type'] ?? 'Pump'}';
    if (!['Pump', 'LED', 'RGB', 'Valve', 'Fan', 'Other'].contains(_type))
      _type = 'Other';
    final ids = item['assigned_user_ids'];
    if (ids is List) _assigned.addAll(ids.map((id) => int.parse('$id')));
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _testMqtt() async {
    final topics = _fields['mqtt_topics']!.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (topics.isEmpty) return;
    setState(() {
      _testing = true;
      _mqttResult = null;
    });
    try {
      final response = await widget.api.post(
        '/admin/test-mqtt',
        body: {
          'admin_id': widget.api.userId,
          'soil_topic': topics.first,
          'leaf_topic': topics.length > 1 ? topics[1] : '',
        },
      );
      if (mounted)
        setState(
          () => _mqttResult = const JsonEncoder.withIndent(
            '  ',
          ).convert(response['results'] ?? []),
        );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final body = <String, dynamic>{
      'admin_id': widget.api.userId,
      'user_ids': _assigned.toList(),
      'device_name': _fields['device_name']!.text.trim(),
      'installed_location': _fields['installed_location']!.text.trim(),
      'farm_id': parseLocalizedInt(_fields['farm_id']!.text),
      'latitude': parseLocalizedDouble(_fields['latitude']!.text),
      'longitude': parseLocalizedDouble(_fields['longitude']!.text),
      if (widget.actuators) ...{
        'device_type': _type,
        'mqtt_publish_topic': _fields['mqtt_publish_topic']!.text.trim(),
        'mqtt_subscribe_topic': _fields['mqtt_subscribe_topic']!.text.trim(),
      } else
        'mqtt_topics': _fields['mqtt_topics']!.text
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
    };
    final path = widget.actuators ? '/admin/actuators' : '/admin/devices';
    try {
      if (widget.item == null) {
        await widget.api.post(path, body: body);
      } else {
        await widget.api.put('$path/${widget.item!['id']}', body: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted)
        setState(() {
          _error = '$e';
          _busy = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: Form(
      key: _form,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            context.ui(widget.item == null ? 'Add device' : 'Edit device'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final entry in labels.entries)
            if (widget.actuators
                ? entry.key != 'mqtt_topics'
                : ![
                    'mqtt_publish_topic',
                    'mqtt_subscribe_topic',
                  ].contains(entry.key))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: TextFormField(
                  controller: _fields[entry.key],
                  enabled: !_busy,
                  maxLines: entry.key == 'mqtt_topics' ? 3 : 1,
                  decoration: InputDecoration(
                    labelText: context.ui(entry.value),
                  ),
                  validator: (v) {
                    if (entry.key == 'device_name' && (v ?? '').trim().isEmpty)
                      return context.tr('required_field');
                    if ([
                          'latitude',
                          'longitude',
                          'farm_id',
                        ].contains(entry.key) &&
                        (v ?? '').isNotEmpty) {
                      final n = parseLocalizedDouble(v!);
                      if (n == null ||
                          !n.isFinite ||
                          (entry.key == 'latitude' && n.abs() > 90) ||
                          (entry.key == 'longitude' && n.abs() > 180) ||
                          (entry.key == 'farm_id' &&
                              (n <= 0 || n != n.roundToDouble())))
                        return context.ui('Invalid value');
                    }
                    return null;
                  },
                ),
              ),
          if (widget.actuators)
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: InputDecoration(labelText: context.ui('Device type')),
              items: [
                for (final t in ['Pump', 'LED', 'RGB', 'Valve', 'Fan', 'Other'])
                  DropdownMenuItem(value: t, child: Text(context.ui(t))),
              ],
              onChanged: _busy ? null : (v) => setState(() => _type = v!),
            ),
          MapLocationPicker(
            latitude: parseLocalizedDouble(_fields['latitude']!.text),
            longitude: parseLocalizedDouble(_fields['longitude']!.text),
            onChanged: (lat, lon) => setState(() {
              _fields['latitude']!.text = lat.toString();
              _fields['longitude']!.text = lon.toString();
            }),
          ),
          if (!widget.actuators) ...[
            OutlinedButton.icon(
              onPressed: _testing || _busy ? null : _testMqtt,
              icon: const Icon(Icons.sensors),
              label: Text(context.ui('Test MQTT connection')),
            ),
            if (_mqttResult != null)
              SelectableText(_mqttResult!, textDirection: TextDirection.ltr),
          ],
          Text(context.ui('Assigned users')),
          for (final u in widget.users)
            CheckboxListTile(
              title: Text('${u['name']}'),
              subtitle: Text('${u['email']}'),
              value: _assigned.contains(u['id']),
              onChanged: _busy
                  ? null
                  : (v) => setState(() {
                      if (v == true) {
                        _assigned.add(u['id'] as int);
                      } else {
                        _assigned.remove(u['id']);
                      }
                    }),
            ),
          if (_error != null) Text(context.errorText(_error!)),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(context.tr(_busy ? 'loading' : 'save')),
          ),
        ],
      ),
    ),
  );
}

class AdminUserDetails extends StatefulWidget {
  const AdminUserDetails({super.key, required this.userId});
  final int userId;
  @override
  State<AdminUserDetails> createState() => _AdminUserDetailsState();
}

class _AdminUserDetailsState extends State<AdminUserDetails> {
  Map? _data;
  String? _error;
  bool _busy = false;
  final _credits = TextEditingController();
  final _costs = <String, TextEditingController>{};
  final _permissions = <String, Map<String, dynamic>>{};
  ApiClient get _api => context.read<ApiClient>();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await _api.get(
        '/admin/users/${widget.userId}/profile',
        query: {'admin_id': _api.userId},
      );
      if (!mounted) return;
      final profile = data['profile'] as Map;
      _credits.text = '${profile['ai_credits'] ?? 0}';
      for (final e in (profile['permissions'] as Map).entries) {
        final config = Map<String, dynamic>.from(e.value as Map);
        _permissions['${e.key}'] = config;
        _costs['${e.key}'] = TextEditingController(text: '${config['cost']}');
      }
      setState(() => _data = data as Map);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  void dispose() {
    _credits.dispose();
    for (final c in _costs.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save(bool credits) async {
    final creditValue = int.tryParse(_credits.text);
    if (credits && (creditValue == null || creditValue < 0)) {
      setState(() => _error = 'Invalid value');
      return;
    }
    for (final e in _costs.entries) {
      final cost = int.tryParse(e.value.text);
      if (!credits && (cost == null || cost < 0)) {
        setState(() => _error = 'Invalid value');
        return;
      }
      if (cost != null) _permissions[e.key]!['cost'] = cost;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api.put(
        '/admin/users/${widget.userId}/${credits ? 'credits' : 'features'}',
        body: {
          'admin_id': _api.userId,
          if (credits) 'ai_credits': creditValue else 'features': _permissions,
        },
      );
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.tr('saved'))));
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.ui('User details'))),
    body: _data == null
        ? (_error == null
              ? const LoadingView()
              : ErrorView(message: _error!, onRetry: _load))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '${_data!['profile']['name']}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text('${_data!['profile']['email']}'),
              TextField(
                controller: _credits,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.tr('credits')),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _save(true),
                child: Text(context.ui('Save credits')),
              ),
              Text(
                context.ui('Feature permissions'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final e in _permissions.entries)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.ui(e.key)),
                        DropdownButtonFormField<String>(
                          initialValue: e.value['state'] as String,
                          items: [
                            for (final state in [
                              'credit_based',
                              'unlimited',
                              'blocked',
                            ])
                              DropdownMenuItem(
                                value: state,
                                child: Text(context.ui(state)),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (v) => setState(() => e.value['state'] = v),
                        ),
                        if (e.value['state'] == 'credit_based')
                          TextField(
                            controller: _costs[e.key],
                            keyboardType: TextInputType.number,
                            enabled: !_busy,
                            decoration: InputDecoration(
                              labelText: context.ui('Credit cost'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              FilledButton(
                onPressed: _busy ? null : () => _save(false),
                child: Text(context.ui('Save permissions')),
              ),
              if (_error != null) Text(context.errorText(_error!)),
              for (final kind in ['devices', 'logs', 'files'])
                ExpansionTile(
                  title: Text(context.ui(kind)),
                  children: [
                    for (final item
                        in (_data![kind] as List? ?? []).whereType<Map>())
                      ListTile(
                        title: Text(
                          '${item['device_name'] ?? item['feature_name'] ?? item['file_name'] ?? item['action'] ?? item['id']}',
                        ),
                        subtitle: Text(
                          '${item['created_at'] ?? item['timestamp'] ?? item['installed_location'] ?? ''}',
                        ),
                      ),
                  ],
                ),
            ],
          ),
  );
}
