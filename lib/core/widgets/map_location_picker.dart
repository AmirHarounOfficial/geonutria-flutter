import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../localization/app_localizations.dart';
import 'app_map.dart';

/// A form-style field that shows the chosen coordinates and opens a full-screen
/// map to pick a location (tap or "use my location"). Mirrors the web
/// `MapLocationPicker`.
class MapLocationPicker extends StatelessWidget {
  const MapLocationPicker({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.onChanged,
    this.label,
  });

  final double? latitude;
  final double? longitude;
  final void Function(double lat, double lon) onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final hasValue = latitude != null && longitude != null;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final picked = await Navigator.of(context).push<LatLng>(
          MaterialPageRoute(
            builder: (_) => _PickerScreen(
              initial: hasValue
                  ? LatLng(latitude!, longitude!)
                  : const LatLng(26.8206, 30.8025), // Egypt centroid default
            ),
          ),
        );
        if (picked != null) onChanged(picked.latitude, picked.longitude);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label ?? 'Location',
          prefixIcon: const Icon(Icons.map_outlined),
        ),
        child: Text(
          hasValue
              ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
              : 'Tap to set on map',
        ),
      ),
    );
  }
}

class _PickerScreen extends StatefulWidget {
  const _PickerScreen({required this.initial});
  final LatLng initial;

  @override
  State<_PickerScreen> createState() => _PickerScreenState();
}

class _PickerScreenState extends State<_PickerScreen> {
  final _controller = MapController();
  late LatLng _selected = widget.initial;
  bool _satellite = true;
  bool _locating = false;

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      setState(() => _selected = here);
      _controller.move(here, 15);
    } catch (_) {
      // ignore location errors; user can still tap
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick location'),
        actions: [
          IconButton(
            tooltip: 'Toggle satellite',
            icon: Icon(_satellite ? Icons.map : Icons.satellite_alt),
            onPressed: () => setState(() => _satellite = !_satellite),
          ),
        ],
      ),
      body: AppMap(
        controller: _controller,
        center: _selected,
        zoom: 13,
        satellite: _satellite,
        markers: [_selected],
        onTap: (p) => setState(() => _selected = p),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'loc',
            onPressed: _locating ? null : _useMyLocation,
            child: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'done',
            onPressed: () => Navigator.of(context).pop(_selected),
            icon: const Icon(Icons.check),
            label: Text(context.tr('confirm')),
          ),
        ],
      ),
    );
  }
}
