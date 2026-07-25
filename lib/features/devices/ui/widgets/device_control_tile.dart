import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../bloc/devices_cubit.dart';
import '../../data/device_models.dart';

/// Renders one [ControlEndpoint] as a switch or a value slider and publishes
/// the configured payload to MQTT when the user acts on it.
///
/// Shared by the device detail screen and the dashboard's quick-controls card
/// so both behave identically; [trailing] lets the detail screen add its
/// edit/delete menu without duplicating the publish logic.
class DeviceControlTile extends StatefulWidget {
  const DeviceControlTile({
    super.key,
    required this.deviceId,
    required this.control,
    this.subtitle,
    this.trailing,
    this.showDivider = true,
  });

  final int deviceId;
  final ControlEndpoint control;

  /// Secondary line under the label — the topic on the detail screen, the
  /// device name on the dashboard.
  final String? subtitle;
  final Widget? trailing;
  final bool showDivider;

  @override
  State<DeviceControlTile> createState() => _DeviceControlTileState();
}

class _DeviceControlTileState extends State<DeviceControlTile> {
  bool _on = false;
  late double _value = widget.control.min;
  bool _busy = false;

  Future<void> _publish(String payload) async {
    setState(() => _busy = true);
    try {
      await context.read<DevicesCubit>().publish(
        widget.deviceId,
        widget.control.topic,
        payload,
      );
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
    final c = widget.control;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsetsDirectional.only(end: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              if (c.isSwitch)
                Switch(
                  value: _on,
                  onChanged: _busy
                      ? null
                      : (v) {
                          setState(() => _on = v);
                          _publish(v ? c.onPayload : c.offPayload);
                        },
                ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
          if (widget.subtitle != null)
            Text(
              widget.subtitle!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (!c.isSwitch)
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _value.clamp(c.min, c.max),
                    min: c.min,
                    max: c.max,
                    label: _value.toStringAsFixed(0),
                    onChanged: (v) => setState(() => _value = v),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text(
                    '${_value.toStringAsFixed(0)}${c.unit ?? ''}',
                    textAlign: TextAlign.end,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _busy
                      ? null
                      : () => _publish(_value.toStringAsFixed(0)),
                ),
              ],
            ),
          if (widget.showDivider) const Divider(height: 8),
        ],
      ),
    );
  }
}
