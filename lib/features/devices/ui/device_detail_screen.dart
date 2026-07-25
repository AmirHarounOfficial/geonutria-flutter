import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_exception.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/bloc/auth_cubit.dart';
import '../bloc/devices_cubit.dart';
import '../data/device_models.dart';
import 'widgets/device_control_tile.dart';

/// Detail + control screen for a single bound device.
class DeviceDetailScreen extends StatelessWidget {
  const DeviceDetailScreen({super.key, required this.deviceId});
  final int deviceId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DevicesCubit, DevicesState>(
      builder: (context, state) {
        MyDevice? device;
        for (final d in state.devices) {
          if (d.id == deviceId) device = d;
        }
        if (device == null) {
          return const Scaffold(body: EmptyView(message: 'Device not found'));
        }
        final dev = device;
        return Scaffold(
          appBar: AppBar(
            title: Text(dev.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _editDevice(context, dev),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, dev),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _InfoCard(device: dev),
              const SizedBox(height: 16),
              _ControlsSection(device: dev),
              const SizedBox(height: 16),
              // Flashing firmware can brick a device, so OTA is admin-only.
              // The backend enforces this too — this just hides the UI.
              if (context.select((AuthCubit c) => c.state.isAdmin))
                _FirmwareSection(device: dev)
              else
                _FirmwareLockedNote(version: dev.firmwareVersion),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, MyDevice dev) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Unbind device?'),
        content: Text('Remove "${dev.name}" from your account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text(context.tr('cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dctx).pop();
              context.read<DevicesCubit>().unbind(dev.id);
              Navigator.of(context).pop();
            },
            child: Text(context.tr('delete')),
          ),
        ],
      ),
    );
  }

  void _editDevice(BuildContext context, MyDevice dev) {
    final cubit = context.read<DevicesCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _EditSheet(device: dev),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.device});
  final MyDevice device;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (device.location != null && device.location!.isNotEmpty)
              Text(device.location!),
            const SizedBox(height: 6),
            Text(
              'Monitored topics: ${device.mqttTopics.join(", ")}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (device.otaTopic != null)
              Text(
                'OTA topic: ${device.otaTopic}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Controls ──────────────────────────────────────────────────────────────────
class _ControlsSection extends StatelessWidget {
  const _ControlsSection({required this.device});
  final MyDevice device;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Controls',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addOrEdit(context, null),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (device.controls.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No controls yet. Add a switch or value endpoint.'),
              )
            else
              for (var i = 0; i < device.controls.length; i++)
                DeviceControlTile(
                  key: ValueKey('${device.id}:${device.controls[i].topic}'),
                  deviceId: device.id,
                  control: device.controls[i],
                  subtitle: device.controls[i].topic,
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => v == 'edit'
                        ? _addOrEdit(context, i)
                        : _delete(context, i),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  void _delete(BuildContext context, int index) {
    final controls = [...device.controls]..removeAt(index);
    context.read<DevicesCubit>().update(device.id, controls: controls);
  }

  void _addOrEdit(BuildContext context, int? index) {
    final cubit = context.read<DevicesCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _ControlEditor(device: device, index: index),
      ),
    );
  }
}

class _ControlEditor extends StatefulWidget {
  const _ControlEditor({required this.device, this.index});
  final MyDevice device;
  final int? index;

  @override
  State<_ControlEditor> createState() => _ControlEditorState();
}

class _ControlEditorState extends State<_ControlEditor> {
  late final ControlEndpoint? _existing = widget.index != null
      ? widget.device.controls[widget.index!]
      : null;

  late final _label = TextEditingController(text: _existing?.label ?? '');
  late final _topic = TextEditingController(text: _existing?.topic ?? '');
  late final _on = TextEditingController(text: _existing?.onPayload ?? '1');
  late final _off = TextEditingController(text: _existing?.offPayload ?? '0');
  late final _min = TextEditingController(text: '${_existing?.min ?? 0}');
  late final _max = TextEditingController(text: '${_existing?.max ?? 100}');
  late final _unit = TextEditingController(text: _existing?.unit ?? '');
  late String _type = _existing?.type ?? 'switch';

  @override
  void dispose() {
    for (final c in [_label, _topic, _on, _off, _min, _max, _unit]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_label.text.trim().isEmpty || _topic.text.trim().isEmpty) return;
    final control = ControlEndpoint(
      label: _label.text.trim(),
      topic: _topic.text.trim(),
      type: _type,
      onPayload: _on.text.trim().isEmpty ? '1' : _on.text.trim(),
      offPayload: _off.text.trim().isEmpty ? '0' : _off.text.trim(),
      min: double.tryParse(_min.text) ?? 0,
      max: double.tryParse(_max.text) ?? 100,
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
    );
    final controls = [...widget.device.controls];
    if (widget.index != null) {
      controls[widget.index!] = control;
    } else {
      controls.add(control);
    }
    context.read<DevicesCubit>().update(widget.device.id, controls: controls);
    Navigator.of(context).pop();
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
              widget.index == null ? 'Add control' : 'Edit control',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _topic,
              decoration: const InputDecoration(labelText: 'Topic'),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'switch',
                  label: Text('Switch'),
                  icon: Icon(Icons.toggle_on),
                ),
                ButtonSegment(
                  value: 'value',
                  label: Text('Value'),
                  icon: Icon(Icons.tune),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 8),
            if (_type == 'switch')
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _on,
                      decoration: const InputDecoration(
                        labelText: 'On payload',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _off,
                      decoration: const InputDecoration(
                        labelText: 'Off payload',
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _min,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _max,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _unit,
                      decoration: const InputDecoration(labelText: 'Unit'),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text(context.tr('save'))),
          ],
        ),
      ),
    );
  }
}

// ── Firmware ─────────────────────────────────────────────────────────────────

/// Shown in place of the OTA controls for non-admin users: the current version
/// stays visible, but pushing an update is not offered.
class _FirmwareLockedNote extends StatelessWidget {
  const _FirmwareLockedNote({required this.version});
  final String? version;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lock_outline),
        title: Text('Firmware${version != null ? ' · $version' : ''}'),
        subtitle: Text(context.tr('firmware_admin_only')),
      ),
    );
  }
}

class _FirmwareSection extends StatefulWidget {
  const _FirmwareSection({required this.device});
  final MyDevice device;

  @override
  State<_FirmwareSection> createState() => _FirmwareSectionState();
}

class _FirmwareSectionState extends State<_FirmwareSection> {
  final _version = TextEditingController();
  PlatformFile? _file;
  bool _busy = false;

  @override
  void dispose() {
    _version.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _file = result.files.single);
    }
  }

  Future<void> _push() async {
    final bytes = _file?.bytes;
    if (bytes == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Pick a firmware file first.')),
        );
      return;
    }
    if (widget.device.otaTopic == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Set an OTA topic first (edit the device).'),
          ),
        );
      return;
    }
    setState(() => _busy = true);
    try {
      final v = await context.read<DevicesCubit>().pushFirmware(
        widget.device.id,
        bytes: bytes,
        fileName: _file!.name,
        version: _version.text.trim().isEmpty
            ? 'unknown'
            : _version.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('OTA command sent (v$v).')));
      setState(() => _file = null);
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Firmware', style: Theme.of(context).textTheme.titleMedium),
            if (widget.device.firmwareVersion != null)
              Text(
                'Current: ${widget.device.firmwareVersion}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pick,
                  icon: const Icon(Icons.attach_file),
                  label: Text(_file?.name ?? 'Pick .bin'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _version,
              decoration: const InputDecoration(labelText: 'Version'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : _push,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.system_update_alt),
              label: const Text('Push update (OTA)'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit device (name/location/topics/ota) ───────────────────────────────────
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.device});
  final MyDevice device;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: widget.device.name);
  late final _location = TextEditingController(
    text: widget.device.location ?? '',
  );
  late final _ota = TextEditingController(text: widget.device.otaTopic ?? '');
  late final List<TextEditingController> _topics =
      widget.device.mqttTopics.isEmpty
      ? [TextEditingController()]
      : widget.device.mqttTopics
            .map((t) => TextEditingController(text: t))
            .toList();

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

  void _save() {
    final topics = _topics
        .map((c) => c.text.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    context.read<DevicesCubit>().update(
      widget.device.id,
      name: _name.text.trim(),
      location: _location.text.trim(),
      mqttTopics: topics,
      otaTopic: _ota.text.trim(),
    );
    Navigator.of(context).pop();
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
            Text('Edit device', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            Text('MQTT topics', style: Theme.of(context).textTheme.titleSmall),
            for (var i = 0; i < _topics.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _topics[i],
                        decoration: InputDecoration(
                          labelText: 'Topic ${i + 1}',
                        ),
                      ),
                    ),
                    if (_topics.length > 1)
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
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
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add topic'),
              ),
            ),
            TextField(
              controller: _ota,
              decoration: const InputDecoration(labelText: 'OTA topic'),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text(context.tr('save'))),
          ],
        ),
      ),
    );
  }
}
