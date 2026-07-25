import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../bloc/devices_cubit.dart';
import '../../data/device_models.dart';

/// Renders one [ControlEndpoint] as a switch or a value slider and publishes
/// the configured payload to MQTT when the user acts on it.
///
/// When the control declares a state topic, the displayed position comes from
/// what the device actually reports (polled by [DevicesCubit]); the local
/// toggle is only an optimistic guess shown until the device confirms.
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
  /// What we just commanded, shown until the device reports the same thing.
  /// Null means "trust the reported state".
  bool? _optimisticOn;
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
        // The command failed, so drop the optimistic position and fall back
        // to whatever the device last reported.
        setState(() => _optimisticOn = null);
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

    return BlocConsumer<DevicesCubit, DevicesState>(
      listenWhen: (a, b) =>
          a.controlStates[c.stateTopic] != b.controlStates[c.stateTopic],
      listener: (context, devicesState) {
        // Once the device confirms our command, stop overriding it so any
        // later change made elsewhere (or by the device itself) shows through.
        final reported = c.parseOnState(
          devicesState.controlStates[c.stateTopic],
        );
        if (_optimisticOn != null && reported == _optimisticOn) {
          setState(() => _optimisticOn = null);
        }
      },
      buildWhen: (a, b) =>
          a.controlStates[c.stateTopic] != b.controlStates[c.stateTopic],
      builder: (context, devicesState) {
        final reportedRaw = c.hasStateFeedback
            ? devicesState.controlStates[c.stateTopic]
            : null;
        final reportedOn = c.parseOnState(reportedRaw);
        final displayedOn = _optimisticOn ?? reportedOn ?? false;

        // Feedback configured but nothing received yet — don't claim "off".
        final unknown =
            c.hasStateFeedback && reportedOn == null && _optimisticOn == null;

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
                      value: displayedOn,
                      onChanged: _busy
                          ? null
                          : (v) {
                              setState(() => _optimisticOn = v);
                              _publish(v ? c.onPayload : c.offPayload);
                            },
                    ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
              _StatusLine(
                subtitle: widget.subtitle,
                control: c,
                reportedRaw: reportedRaw,
                unknown: unknown,
                pending: _optimisticOn != null,
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
      },
    );
  }
}

/// Secondary line: the caller's subtitle plus, when state feedback is
/// configured, what the device currently reports.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.subtitle,
    required this.control,
    required this.reportedRaw,
    required this.unknown,
    required this.pending,
  });

  final String? subtitle;
  final ControlEndpoint control;
  final String? reportedRaw;
  final bool unknown;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final small = theme.textTheme.bodySmall;

    String? status;
    Color? color;
    if (!control.hasStateFeedback) {
      status = null;
    } else if (unknown) {
      status = 'awaiting device…';
      color = theme.colorScheme.outline;
    } else if (pending) {
      status = 'sending…';
      color = theme.colorScheme.outline;
    } else if (reportedRaw != null) {
      final unit = control.isSwitch ? '' : (control.unit ?? '');
      status = 'device: $reportedRaw$unit';
      color = theme.colorScheme.primary;
    }

    if (subtitle == null && status == null) return const SizedBox.shrink();

    return Row(
      children: [
        if (subtitle != null)
          Flexible(
            child: Text(
              subtitle!,
              style: small,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        if (subtitle != null && status != null) Text(' · ', style: small),
        if (status != null) Text(status, style: small?.copyWith(color: color)),
      ],
    );
  }
}
