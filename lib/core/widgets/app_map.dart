import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Reusable map built on flutter_map, mirroring the web Leaflet setup:
/// an OpenStreetMap street layer or an ArcGIS World Imagery satellite layer,
/// both free and key-less. Supports tap-to-pick a point and rendering markers,
/// a polygon, and a polyline overlay.
class AppMap extends StatelessWidget {
  const AppMap({
    super.key,
    required this.center,
    this.zoom = 13,
    this.satellite = false,
    this.markers = const [],
    this.polygonPoints,
    this.onTap,
    this.controller,
    this.interactive = true,
  });

  final LatLng center;
  final double zoom;
  final bool satellite;
  final List<LatLng> markers;
  final List<LatLng>? polygonPoints;
  final void Function(LatLng point)? onTap;
  final MapController? controller;
  final bool interactive;

  static const _osmUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _esriUrl =
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        onTap: onTap == null ? null : (_, point) => onTap!(point),
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: satellite ? _esriUrl : _osmUrl,
          userAgentPackageName: 'ai.geonutria.app',
          maxZoom: 19,
        ),
        if (polygonPoints != null && polygonPoints!.length >= 2)
          PolygonLayer(
            polygons: [
              Polygon(
                points: polygonPoints!,
                color: Colors.orange.withValues(alpha: 0.25),
                borderColor: Colors.orange,
                borderStrokeWidth: 2,
              ),
            ],
          ),
        if (polygonPoints != null && polygonPoints!.isNotEmpty)
          MarkerLayer(
            markers: [
              for (final p in polygonPoints!)
                Marker(
                  point: p,
                  width: 14,
                  height: 14,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        if (markers.isNotEmpty)
          MarkerLayer(
            markers: [
              for (final m in markers)
                Marker(
                  point: m,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on,
                      color: Colors.red, size: 36),
                ),
            ],
          ),
      ],
    );
  }
}
