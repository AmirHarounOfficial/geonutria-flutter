import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../devices/bloc/devices_cubit.dart';
import '../../../devices/ui/widgets/device_control_tile.dart';

/// Surfaces every switch/value control the user has configured on their bound
/// devices directly on the dashboard, so acting on a device never requires
/// navigating into My Devices.
///
/// Renders nothing until at least one control exists. Controls are grouped by
/// device, with [preferredDeviceId] (the device selected on the dashboard)
/// floated to the top.
class QuickControlsCard extends StatelessWidget {
  const QuickControlsCard({super.key, this.preferredDeviceId});

  final int? preferredDeviceId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DevicesCubit, DevicesState>(
      builder: (context, state) {
        final withControls =
            state.devices.where((d) => d.controls.isNotEmpty).toList()
              ..sort((a, b) {
                if (a.id == preferredDeviceId) return -1;
                if (b.id == preferredDeviceId) return 1;
                return 0;
              });
        if (withControls.isEmpty) return const SizedBox.shrink();

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                const SizedBox(height: 4),
                for (final device in withControls)
                  for (var i = 0; i < device.controls.length; i++)
                    DeviceControlTile(
                      key: ValueKey('${device.id}:${device.controls[i].topic}'),
                      deviceId: device.id,
                      control: device.controls[i],
                      subtitle: withControls.length > 1
                          ? device.name
                          : device.controls[i].topic,
                      showDivider:
                          !(device == withControls.last &&
                              i == device.controls.length - 1),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
