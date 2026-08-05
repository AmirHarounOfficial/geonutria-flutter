import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../dashboard/bloc/history_cubit.dart' show LoadState;
import '../../bloc/control_cubit.dart';
import 'actuator_tile.dart';

/// Grid of the user's actuators at the top of the dashboard, so operating a
/// pump or a light never requires navigating anywhere.
///
/// Renders nothing when the account has no actuators — they are provisioned by
/// an administrator, so an empty grid would just be noise for most users.
class ActuatorsCard extends StatelessWidget {
  const ActuatorsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ControlCubit, ControlState>(
      buildWhen: (a, b) => a.actuators != b.actuators || a.state != b.state,
      builder: (context, state) {
        if (state.actuators.isEmpty) {
          // Only worth explaining once loading has actually finished.
          if (state.state != LoadState.loaded) return const SizedBox.shrink();
          return const SizedBox.shrink();
        }

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
                    final columns = (constraints.maxWidth / 168).floor().clamp(
                      2,
                      4,
                    );
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: state.actuators.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 1.45,
                      ),
                      itemBuilder: (context, i) {
                        final a = state.actuators[i];
                        return ActuatorTile(key: ValueKey(a.id), actuator: a);
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
