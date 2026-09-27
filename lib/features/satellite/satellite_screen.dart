import 'package:geonutria_mobile/core/localization/localized_number.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/app_map.dart';
import '../../core/widgets/data_uri_image.dart';
import '../../core/widgets/image_pick_sheet.dart';
import '../../core/widgets/picked_image.dart';
import '../../core/widgets/status_views.dart';
import '../ai_models/data/model_repository.dart';
import '../auth/bloc/auth_cubit.dart';
import '../dashboard/bloc/history_cubit.dart' show LoadState;
import 'data/satellite_models.dart';
import 'data/satellite_repository.dart';
import 'satellite_cubit.dart';

/// Satellite analysis: vegetation indices over a point/polygon, plus aerial
/// palm counting.
class SatelliteScreen extends StatelessWidget {
  const SatelliteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<ApiClient>();
    return BlocProvider(
      create: (ctx) => SatelliteCubit(
        SatelliteRepository(api),
        ModelRepository(api),
        ctx.read<AuthCubit>(),
      ),
      child: const _SatelliteView(),
    );
  }
}

class _SatelliteView extends StatelessWidget {
  const _SatelliteView();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: context.tr('tab_indices')),
              Tab(text: context.tr('tab_palm_count')),
            ],
          ),
          Expanded(child: TabBarView(children: [_IndicesTab(), _PalmTab()])),
        ],
      ),
    );
  }
}

class _IndicesTab extends StatefulWidget {
  const _IndicesTab();
  @override
  State<_IndicesTab> createState() => _IndicesTabState();
}

class _IndicesTabState extends State<_IndicesTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _map = MapController();
  bool _polygonMode = false;
  LatLng? _point;
  final List<LatLng> _polygon = [];
  bool _locating = false;

  DateTime _start = DateTime.now().subtract(Duration(days: 30));
  DateTime _end = DateTime.now();
  int _compareValue = 3;
  String _compareUnit = 'months';
  double _cloud = 10;
  double _radius = 1.0;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(context.ui('Location permission was denied.')),
              ),
            );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _point = here;
        if (_polygonMode) {
          _polygon.add(here);
        }
      });
      _map.move(here, 14);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(context.errorText('$e'))));
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _onTap(LatLng p) {
    setState(() {
      if (_polygonMode) {
        if (_polygon.length < 12) _polygon.add(p);
      } else {
        _point = p;
      }
    });
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2017),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  void _analyze() {
    final fmt = DateFormat('yyyy-MM-dd');
    final usePolygon = _polygonMode && _polygon.length >= 3;
    if (!usePolygon && _point == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              context.ui('Tap the map to set a point or draw a polygon.'),
            ),
          ),
        );
      return;
    }
    context.read<SatelliteCubit>().analyze(
      lat: usePolygon ? null : _point!.latitude,
      lon: usePolygon ? null : _point!.longitude,
      radiusKm: _radius,
      startDate: fmt.format(_start),
      endDate: fmt.format(_end),
      compareValue: _compareValue,
      compareUnit: _compareUnit,
      maxCloudCover: _cloud.round(),
      polygonCoords: usePolygon
          ? [
              for (final p in _polygon) [p.latitude, p.longitude],
            ]
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<SatelliteCubit, SatelliteState>(
      builder: (context, state) {
        final busy = state.analysisState == LoadState.loading;
        return ListView(
          padding: EdgeInsets.all(16),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 260,
                child: Stack(
                  children: [
                    AppMap(
                      controller: _map,
                      center: _point ?? LatLng(26.8206, 30.8025),
                      zoom: 6,
                      satellite: true,
                      onTap: _onTap,
                      markers: _polygonMode || _point == null ? [] : [_point!],
                      polygonPoints: _polygonMode ? _polygon : null,
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: FloatingActionButton.small(
                        heroTag: 'sat_loc',
                        onPressed: _locating ? null : _useMyLocation,
                        backgroundColor: Theme.of(context).colorScheme.surface,
                        child: _locating
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.my_location),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            Row(
              children: [
                FilterChip(
                  label: Text(context.ui('Polygon mode')),
                  selected: _polygonMode,
                  onSelected: (v) => setState(() => _polygonMode = v),
                ),
                Spacer(),
                if (_polygonMode && _polygon.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(_polygon.clear),
                    icon: Icon(Icons.clear, size: 18),
                    label: Text('${context.ui('Clear')} (${_polygon.length})'),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Start',
                    date: _start,
                    onTap: () => _pickDate(true),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'End',
                    date: _end,
                    onTap: () => _pickDate(false),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: '$_compareValue',
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: context.ui('Compare with past'),
                    ),
                    onChanged: (v) => _compareValue = parseLocalizedInt(v) ?? 3,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _compareUnit,
                    decoration: InputDecoration(labelText: context.ui('Unit')),
                    items: [
                      DropdownMenuItem(
                        value: 'weeks',
                        child: Text(context.ui('weeks')),
                      ),
                      DropdownMenuItem(
                        value: 'months',
                        child: Text(context.ui('months')),
                      ),
                      DropdownMenuItem(
                        value: 'years',
                        child: Text(context.ui('years')),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => _compareUnit = v ?? 'months'),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text('${context.ui('Max cloud cover')} ${_cloud.round()}%'),
            Slider(
              value: _cloud,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${_cloud.round()}%',
              onChanged: (v) => setState(() => _cloud = v),
            ),
            if (!_polygonMode) ...[
              Text('${context.ui('Radius')} ${_radius.toStringAsFixed(1)} km'),
              Slider(
                value: _radius,
                min: 0.2,
                max: 5,
                divisions: 24,
                label: '${_radius.toStringAsFixed(1)} km',
                onChanged: (v) => setState(() => _radius = v),
              ),
            ],
            SizedBox(height: 8),
            FilledButton.icon(
              onPressed: busy ? null : _analyze,
              icon: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(Icons.satellite_alt),
              label: Text(context.ui('Analyze  ·  5 ⚡')),
            ),
            if (state.analysisState == LoadState.error &&
                state.error != null) ...[
              SizedBox(height: 16),
              ErrorView(message: state.error!),
            ],
            if (state.result != null) ...[
              SizedBox(height: 16),
              _ResultMeta(result: state.result!),
              SizedBox(height: 8),
              for (final idx in state.result!.indices) _IndexCard(index: idx),
            ],
          ],
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: context.ui(label)),
        child: Text(DateFormat('yyyy-MM-dd').format(date)),
      ),
    );
  }
}

class _ResultMeta extends StatelessWidget {
  const _ResultMeta({required this.result});
  final SatelliteResult result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${context.ui('Current')} ${result.dateCurrent}   ·   ${context.ui('Past')}: ${result.datePast}',
            ),
            SizedBox(height: 4),
            Text('${context.ui('Area')} ${result.areaKm2} km²'),
          ],
        ),
      ),
    );
  }
}

class _IndexCard extends StatelessWidget {
  const _IndexCard({required this.index});
  final IndexResult index;

  @override
  Widget build(BuildContext context) {
    final up = index.delta >= 0;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  index.key.toUpperCase(),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Spacer(),
                Text(
                  index.currentVal.toStringAsFixed(3),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SizedBox(width: 6),
                Icon(
                  up ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: up ? Colors.green : Colors.red,
                ),
                Text(
                  index.delta.abs().toStringAsFixed(3),
                  style: TextStyle(color: up ? Colors.green : Colors.red),
                ),
              ],
            ),
            Text(
              context.tr('sat_${index.currentInsight}'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PlotImage(label: 'Now', url: index.currentImage),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _PlotImage(label: 'Past', url: index.pastImage),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlotImage extends StatelessWidget {
  const _PlotImage({required this.label, required this.url});
  final String label;
  final String? url;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(context.ui(label), style: Theme.of(context).textTheme.labelSmall),
        SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 1,
            child: url == null
                ? Container(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  )
                : CachedNetworkImage(
                    imageUrl: url!,
                    fit: BoxFit.cover,
                    placeholder: (_, _) =>
                        Center(child: CircularProgressIndicator()),
                    errorWidget: (_, _, _) => Icon(Icons.broken_image),
                  ),
          ),
        ),
      ],
    );
  }
}

class _PalmTab extends StatefulWidget {
  const _PalmTab();
  @override
  State<_PalmTab> createState() => _PalmTabState();
}

class _PalmTabState extends State<_PalmTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  XFile? _file;

  Future<void> _pick() async {
    final picked = await pickImage(context);
    if (picked != null) {
      setState(() => _file = picked);
      if (mounted) context.read<SatelliteCubit>().countPalms(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<SatelliteCubit, SatelliteState>(
      builder: (context, state) {
        final busy = state.palmState == LoadState.loading;
        return ListView(
          padding: EdgeInsets.all(16),
          children: [
            Text(
              context.ui('Upload an aerial image to count palm trees (5 ⚡).'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            SizedBox(height: 12),
            InkWell(
              onTap: busy ? null : _pick,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _file == null
                    ? Center(child: Icon(Icons.add_a_photo_outlined, size: 40))
                    : PickedImage(file: _file!),
              ),
            ),
            if (busy)
              Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            if (state.palm != null) ...[
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        '${state.palm!.count}',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      Text(context.ui('palm trees detected')),
                      if (state.palm!.annotatedImage != null) ...[
                        SizedBox(height: 12),
                        DataUriImage(
                          dataUri: state.palm!.annotatedImage!,
                          height: 260,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
