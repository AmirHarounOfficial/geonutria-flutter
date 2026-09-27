import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/map_location_picker.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/bloc/auth_cubit.dart';
import '../../dashboard/bloc/history_cubit.dart' show LoadState;
import '../bloc/devices_cubit.dart';
import '../data/device_models.dart' show DeviceHealth;
import 'device_detail_screen.dart';

/// "My Devices" — list bound devices and bind new ones.
///
/// The [DevicesCubit] is provided by the shell so the dashboard shares the
/// same device list and control state.
class MyDevicesScreen extends StatelessWidget {
  const MyDevicesScreen({super.key});

  @override
  Widget build(BuildContext context) => const _MyDevicesView();
}

class _MyDevicesView extends StatelessWidget {
  const _MyDevicesView();

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select(
      (AuthCubit c) =>
          c.state.isAdmin ||
          c.state.userId == 1 ||
          c.state.role?.toLowerCase() == 'admin',
    );
    return BlocConsumer<DevicesCubit, DevicesState>(
      listenWhen: (a, b) =>
          a.error != b.error && b.error != null && b.state != LoadState.error,
      listener: (ctx, state) {
        ScaffoldMessenger.of(ctx)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(context.errorText(state.error!))),
          );
      },
      builder: (context, state) {
        return Scaffold(
          body: switch (state.state) {
            LoadState.loading => LoadingView(),
            LoadState.error => ErrorView(
              message: state.error ?? context.tr('error_generic'),
              onRetry: () => context.read<DevicesCubit>().load(),
            ),
            _ =>
              state.devices.isEmpty
                  ? EmptyView(
                      message: 'No devices yet. Bind your first device.',
                      icon: Icons.router_outlined,
                    )
                  : RefreshIndicator(
                      onRefresh: () => context.read<DevicesCubit>().load(),
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: state.devices.length,
                        itemBuilder: (ctx, i) {
                          final d = state.devices[i];
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Icon(Icons.router)),
                              title: Row(
                                children: [
                                  Expanded(child: Text(d.name)),
                                  // Only shown when the server actually
                                  // reports freshness.
                                  if (d.healthKnown)
                                    _HealthChip(health: d.health),
                                ],
                              ),
                              subtitle: Text(
                                [
                                  if (d.location != null &&
                                      d.location!.isNotEmpty)
                                    d.location,
                                  if (d.healthKnown)
                                    'Last reading ${d.lastSeenLabel}',
                                  if (d.controls.isNotEmpty)
                                    '${d.controls.length} ${d.controls.length == 1 ? "control" : "controls"}',
                                  if (d.firmwareVersion != null)
                                    'fw ${d.firmwareVersion}',
                                ].whereType<String>().join('\n'),
                              ),
                              isThreeLine: true,
                              trailing: Icon(Icons.chevron_right),
                              onTap: () {
                                final cubit = ctx.read<DevicesCubit>();
                                Navigator.of(ctx).push(
                                  MaterialPageRoute(
                                    builder: (_) => BlocProvider.value(
                                      value: cubit,
                                      child: DeviceDetailScreen(deviceId: d.id),
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
          },
          floatingActionButton: isAdmin
              ? FloatingActionButton.extended(
                  onPressed: () => _showBindSheet(context),
                  icon: Icon(Icons.add),
                  label: Text(context.ui('Bind device')),
                )
              : null,
        );
      },
    );
  }

  void _showBindSheet(BuildContext context) {
    final cubit = context.read<DevicesCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const _BindSheet()),
    );
  }
}

/// Connectivity indicator for a device card.
///
/// Colour plus text, never colour alone — the distinction has to survive a
/// colour-blind reader and a quick glance in sunlight.
class _HealthChip extends StatelessWidget {
  const _HealthChip({required this.health});
  final DeviceHealth health;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, color) = switch (health) {
      DeviceHealth.online => ('Online', Colors.green),
      DeviceHealth.stale => ('Stale', Colors.orange),
      DeviceHealth.offline => ('Offline', scheme.error),
      DeviceHealth.never => ('No data', scheme.outline),
    };
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BindSheet extends StatefulWidget {
  const _BindSheet();
  @override
  State<_BindSheet> createState() => _BindSheetState();
}

class _BindSheetState extends State<_BindSheet> {
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _ota = TextEditingController();
  final List<TextEditingController> _topics = [TextEditingController()];
  double? _lat;
  double? _lon;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _ota.dispose();
    for (final c in _topics) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final topics = _topics
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(context.ui('Enter a device name.'))),
        );
      return;
    }
    setState(() => _busy = true);
    final ok = await context.read<DevicesCubit>().bind(
      name: name,
      mqttTopics: topics,
      otaTopic: _ota.text.trim().isEmpty ? null : _ota.text.trim(),
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      latitude: _lat,
      longitude: _lon,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.ui('Bind a device'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: context.ui('Device name')),
            ),
            SizedBox(height: 10),
            MapLocationPicker(
              label: 'Location (optional)',
              latitude: _lat,
              longitude: _lon,
              onChanged: (la, lo) => setState(() {
                _lat = la;
                _lon = lo;
              }),
            ),
            SizedBox(height: 16),
            Text(
              context.ui('MQTT topics (monitored)'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: 4),
            for (var i = 0; i < _topics.length; i++)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _topics[i],
                        decoration: InputDecoration(
                          labelText: '${context.ui('Topic')} ${i + 1}',
                          hintText: context.ui('e.g. farm/soil/device1'),
                        ),
                      ),
                    ),
                    if (_topics.length > 1)
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() => _topics.removeAt(i)),
                      ),
                  ],
                ),
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _topics.add(TextEditingController())),
                icon: Icon(Icons.add, size: 18),
                label: Text(context.ui('Add topic')),
              ),
            ),
            SizedBox(height: 8),
            TextField(
              controller: _ota,
              decoration: InputDecoration(
                labelText: context.ui('OTA topic (optional)'),
                hintText: context.ui(
                  'topic the device listens on for firmware',
                ),
              ),
            ),
            SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(context.tr('save')),
            ),
          ],
        ),
      ),
    );
  }
}
