import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/app_map.dart';
import '../../../core/widgets/status_views.dart';
import '../../auth/bloc/auth_cubit.dart';
import '../bloc/dashboard_cubit.dart';
import '../bloc/history_cubit.dart';
import '../bloc/manual_diagnosis_cubit.dart';
import '../bloc/weather_cubit.dart';
import '../data/iot_repository.dart';
import 'sensor_meta.dart';
import 'widgets/diagnosis_card.dart';
import 'widgets/history_chart.dart';
import 'widgets/manual_entry_form.dart';
import 'widgets/sensor_card.dart';
import 'widgets/weather_chart.dart';

/// The IoT monitoring dashboard: device selector + Live / History / Weather /
/// Manual tabs.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = IotRepository(context.read<ApiClient>());
    final auth = context.read<AuthCubit>();
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => DashboardCubit(repo, auth)..loadDevices()),
        BlocProvider(create: (_) => HistoryCubit(repo, auth)),
        BlocProvider(create: (_) => WeatherCubit(repo)),
        BlocProvider(create: (_) => ManualDiagnosisCubit(repo, auth)),
      ],
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state.status == DashStatus.loadingDevices ||
            state.status == DashStatus.initial) {
          return const LoadingView();
        }
        if (state.status == DashStatus.error) {
          return ErrorView(
            message: state.error ?? context.tr('error_generic'),
            onRetry: () => context.read<DashboardCubit>().loadDevices(),
          );
        }
        if (state.devices.isEmpty) {
          return EmptyView(
            message: context.tr('no_devices'),
            icon: Icons.sensors_off,
          );
        }
        return DefaultTabController(
          length: 4,
          child: Column(
            children: [
              _DeviceSelector(state: state),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: [
                  Tab(text: context.tr('tab_live')),
                  Tab(text: context.tr('tab_history')),
                  Tab(text: context.tr('tab_weather')),
                  Tab(text: context.tr('tab_manual')),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _LiveTab(state: state),
                    _HistoryTab(deviceId: state.selectedId!),
                    _WeatherTab(deviceId: state.selectedId!),
                    const ManualEntryForm(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DeviceSelector extends StatelessWidget {
  const _DeviceSelector({required this.state});
  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: state.selectedId,
              decoration: InputDecoration(
                labelText: context.tr('select_device'),
                prefixIcon: const Icon(Icons.sensors),
                isDense: true,
              ),
              items: [
                for (final d in state.devices)
                  DropdownMenuItem(value: d.id, child: Text(d.name)),
              ],
              onChanged: (v) {
                if (v != null) context.read<DashboardCubit>().selectDevice(v);
              },
            ),
          ),
          IconButton(
            tooltip: '${context.tr('refresh')} · 1 ⚡',
            onPressed: state.statusLoading
                ? null
                : () => context.read<DashboardCubit>().refresh(),
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
    );
  }
}

class _LiveTab extends StatelessWidget {
  const _LiveTab({required this.state});
  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    if (state.statusLoading && state.iot == null) {
      return const LoadingView();
    }
    final iot = state.iot;
    if (iot == null) {
      return ErrorView(
        message: context.tr('no_data'),
        onRetry: () => context.read<DashboardCubit>().loadStatus(),
      );
    }
    final device = state.selectedDevice;
    final sensors = [
      for (final m in SensorMeta.all)
        if (iot.sensors.containsKey(m.key)) (m, iot.sensors[m.key]!),
    ];

    return RefreshIndicator(
      onRefresh: () => context.read<DashboardCubit>().loadStatus(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MqttBadge(status: iot.mqttStatus, live: iot.hasLiveData),
          const SizedBox(height: 12),
          DiagnosisCard(diagnosis: iot.diagnosis),
          const SizedBox(height: 16),
          if (!iot.hasLiveData)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No live data from this device yet. Try Refresh, or use Manual entry.',
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                for (final (meta, value) in sensors)
                  SensorCard(meta: meta, value: value),
              ],
            ),
          if (device != null && device.hasLocation) ...[
            const SizedBox(height: 16),
            Text('Device location',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 200,
                child: AppMap(
                  center: LatLng(device.latitude!, device.longitude!),
                  zoom: 14,
                  satellite: true,
                  interactive: false,
                  markers: [LatLng(device.latitude!, device.longitude!)],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MqttBadge extends StatelessWidget {
  const _MqttBadge({required this.status, required this.live});
  final String status;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final connected = status.toLowerCase().contains('connect') || live;
    final color = connected ? Colors.green : Colors.grey;
    return Row(
      children: [
        Icon(Icons.circle, size: 12, color: color),
        const SizedBox(width: 8),
        Text('MQTT: $status'),
      ],
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab({required this.deviceId});
  final int deviceId;

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryCubit>().load(widget.deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<HistoryCubit, HistoryState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final iv in HistoryState.intervals)
                  ChoiceChip(
                    label: Text(iv),
                    selected: state.interval == iv,
                    onSelected: (_) => context
                        .read<HistoryCubit>()
                        .load(widget.deviceId, interval: iv),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.state == LoadState.loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: LoadingView(),
              )
            else if (state.state == LoadState.error)
              ErrorView(
                message: state.error ?? context.tr('error_generic'),
                onRetry: () => context.read<HistoryCubit>().load(widget.deviceId),
              )
            else if (state.points.isEmpty)
              EmptyView(message: context.tr('no_data'))
            else
              HistoryChart(points: state.points),
          ],
        );
      },
    );
  }
}

class _WeatherTab extends StatefulWidget {
  const _WeatherTab({required this.deviceId});
  final int deviceId;

  @override
  State<_WeatherTab> createState() => _WeatherTabState();
}

class _WeatherTabState extends State<_WeatherTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeatherCubit>().load(widget.deviceId);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<WeatherCubit, WeatherState>(
      builder: (context, state) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final iv in WeatherState.intervals)
                  ChoiceChip(
                    label: Text(iv),
                    selected: state.interval == iv,
                    onSelected: (_) => context
                        .read<WeatherCubit>()
                        .load(widget.deviceId, interval: iv),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (state.state == LoadState.loading)
              const Padding(
                  padding: EdgeInsets.all(40), child: LoadingView())
            else if (state.state == LoadState.error)
              ErrorView(
                message: state.error ?? context.tr('error_generic'),
                onRetry: () => context.read<WeatherCubit>().load(widget.deviceId),
              )
            else if (state.points.isEmpty)
              EmptyView(message: context.tr('no_data'))
            else
              WeatherChart(points: state.points),
          ],
        );
      },
    );
  }
}
