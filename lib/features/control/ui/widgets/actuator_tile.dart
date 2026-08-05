import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/app_exception.dart';
import '../../bloc/control_cubit.dart';
import '../../data/control_models.dart';

/// Icon and label for each actuator kind.
({IconData icon, String label}) actuatorMeta(ActuatorType t) => switch (t) {
  ActuatorType.pump => (icon: Icons.water_drop, label: 'Pump'),
  ActuatorType.led => (icon: Icons.lightbulb_outline, label: 'LED'),
  ActuatorType.rgb => (icon: Icons.palette_outlined, label: 'RGB'),
  ActuatorType.valve => (icon: Icons.tune, label: 'Valve'),
  ActuatorType.fan => (icon: Icons.air, label: 'Fan'),
  ActuatorType.other => (icon: Icons.toggle_on_outlined, label: 'Device'),
};

/// One actuator as a compact tile in the dashboard grid.
///
/// The displayed position comes from the server's combined view — its stored
/// power flag plus any MQTT feedback — with a local optimistic override that
/// reverts if the command is refused, matching the web dashboard.
class ActuatorTile extends StatefulWidget {
  const ActuatorTile({super.key, required this.actuator});

  final Actuator actuator;

  @override
  State<ActuatorTile> createState() => _ActuatorTileState();
}

class _ActuatorTileState extends State<ActuatorTile> {
  bool? _optimisticOn;
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggle(bool next) async {
    setState(() {
      _optimisticOn = next;
      _busy = true;
    });
    try {
      await context.read<ControlCubit>().command(
        widget.actuator.id,
        action: next ? 'on' : 'off',
      );
    } on AppException catch (e) {
      if (mounted) setState(() => _optimisticOn = null);
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendValue({
    required String action,
    required Object value,
    required String confirmation,
  }) async {
    setState(() => _busy = true);
    try {
      await context.read<ControlCubit>().command(
        widget.actuator.id,
        action: action,
        value: value,
      );
      _snack(confirmation);
    } on AppException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.actuator;
    final theme = Theme.of(context);
    final meta = actuatorMeta(a.type);

    return BlocBuilder<ControlCubit, ControlState>(
      buildWhen: (x, y) => x.liveStates[a.id] != y.liveStates[a.id],
      builder: (context, controlState) {
        final reported = controlState.isOn(a.id);
        // Once the server agrees with us, stop overriding it.
        if (_optimisticOn != null && _optimisticOn == reported) {
          _optimisticOn = null;
        }
        final on = _optimisticOn ?? reported;

        return Material(
          color: on
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _busy ? null : () => _toggle(!on),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        meta.icon,
                        size: 18,
                        color: on
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.outline,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          a.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: on
                                ? theme.colorScheme.onPrimaryContainer
                                : null,
                          ),
                        ),
                      ),
                      if (_busy)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        SizedBox(
                          height: 24,
                          child: FittedBox(
                            child: Switch(
                              value: on,
                              onChanged: (v) => _toggle(v),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          on ? 'On · ${meta.label}' : 'Off · ${meta.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: on
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.outline,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      // Brightness and colour live behind a button so the tile
                      // stays readable at grid size.
                      if (a.supportsBrightness)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                            width: 30,
                            height: 30,
                          ),
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          tooltip: a.supportsColour ? 'Colour' : 'Brightness',
                          icon: Icon(
                            a.supportsColour
                                ? Icons.color_lens_outlined
                                : Icons.brightness_6_outlined,
                          ),
                          onPressed: _busy ? null : () => _openTuner(a),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _openTuner(Actuator a) {
    final cubit = context.read<ControlCubit>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: _ActuatorTuner(
          actuator: a,
          onBrightness: (v) => _sendValue(
            action: 'set_brightness',
            value: v,
            confirmation: '${a.name} brightness set to $v%.',
          ),
          onColour: (rgb, brightness) => _sendValue(
            action: 'set_rgb',
            value: {
              'r': rgb.r,
              'g': rgb.g,
              'b': rgb.b,
              'brightness': brightness,
            },
            confirmation: '${a.name} colour updated.',
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet for brightness, and colour on RGB units.
class _ActuatorTuner extends StatefulWidget {
  const _ActuatorTuner({
    required this.actuator,
    required this.onBrightness,
    required this.onColour,
  });

  final Actuator actuator;
  final ValueChanged<int> onBrightness;
  final void Function(({int r, int g, int b}) rgb, int brightness) onColour;

  @override
  State<_ActuatorTuner> createState() => _ActuatorTunerState();
}

class _ActuatorTunerState extends State<_ActuatorTuner> {
  late double _brightness = widget.actuator.brightness.toDouble();
  late double _r = widget.actuator.colour.r.toDouble();
  late double _g = widget.actuator.colour.g.toDouble();
  late double _b = widget.actuator.colour.b.toDouble();

  @override
  Widget build(BuildContext context) {
    final a = widget.actuator;
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(a.name, style: theme.textTheme.titleLarge),
          const SizedBox(height: 16),

          Text('Brightness', style: theme.textTheme.labelLarge),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _brightness,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${_brightness.round()}%',
                  onChanged: (v) => setState(() => _brightness = v),
                ),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${_brightness.round()}%',
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),

          if (a.supportsColour) ...[
            const SizedBox(height: 8),
            Text('Colour', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Color.fromARGB(
                    255,
                    _r.round(),
                    _g.round(),
                    _b.round(),
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
              ),
            ),
            _channel('Red', _r, Colors.red, (v) => setState(() => _r = v)),
            _channel('Green', _g, Colors.green, (v) => setState(() => _g = v)),
            _channel('Blue', _b, Colors.blue, (v) => setState(() => _b = v)),
          ],

          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (a.supportsColour) {
                widget.onColour((
                  r: _r.round(),
                  g: _g.round(),
                  b: _b.round(),
                ), _brightness.round());
              } else {
                widget.onBrightness(_brightness.round());
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _channel(
    String label,
    double value,
    Color colour,
    ValueChanged<double> onChanged,
  ) => Row(
    children: [
      SizedBox(
        width: 48,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(activeTrackColor: colour),
          child: Slider(value: value, min: 0, max: 255, onChanged: onChanged),
        ),
      ),
      SizedBox(
        width: 36,
        child: Text('${value.round()}', textAlign: TextAlign.end),
      ),
    ],
  );
}
