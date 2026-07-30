import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../devices/bloc/devices_cubit.dart';
import '../../../devices/data/device_models.dart';
import '../../../devices/ui/widgets/device_control_tile.dart';

/// Surfaces every switch/value control the user has configured on their bound
/// devices directly on the dashboard, as a grid of tappable tiles, so acting
/// on a device never requires navigating into My Devices.
///
/// Renders nothing until at least one control exists. Controls are ordered
/// with [preferredDeviceId] (the device selected on the dashboard) first.
class QuickControlsCard extends StatelessWidget {
  const QuickControlsCard({super.key, this.preferredDeviceId});

  final int? preferredDeviceId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DevicesCubit, DevicesState>(
      buildWhen: (a, b) => a.devices != b.devices,
      builder: (context, state) {
        final withControls =
            state.devices.where((d) => d.controls.isNotEmpty).toList()
              ..sort((a, b) {
                if (a.id == preferredDeviceId) return -1;
                if (b.id == preferredDeviceId) return 1;
                return 0;
              });
        if (withControls.isEmpty) return const SizedBox.shrink();

        // Flatten to (device, control) pairs so the grid lays out evenly
        // regardless of how the controls are distributed across devices.
        final entries = <({MyDevice device, ControlEndpoint control})>[
          for (final d in withControls)
            for (final c in d.controls) (device: d, control: c),
        ];
        final multiDevice = withControls.length > 1;

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      context.tr('quick_controls'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Aim for ~168px tiles, clamped to 2–4 columns.
                    final columns = (constraints.maxWidth / 168).floor().clamp(
                      2,
                      4,
                    );
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: entries.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.45,
                      ),
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        return DeviceControlTile(
                          key: ValueKey('${e.device.id}:${e.control.topic}'),
                          layout: ControlTileLayout.tile,
                          deviceId: e.device.id,
                          control: e.control,
                          subtitle: multiDevice ? e.device.name : null,
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
