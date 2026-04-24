import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';

class MapTab extends ConsumerWidget {
  const MapTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(trackingProvider);
    final points = tracking.stops.map((s) => s.position).toList();
    final status = tracking.routeCompleted
        ? 'Route complete'
        : !tracking.routeStarted
        ? 'Waiting for route start'
        : tracking.isGpsStale
        ? 'GPS stale, showing last known position'
        : 'Live';

    return SafeArea(
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: tracking.busPosition,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.viscous_frontend',
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: points,
                    color: const Color(0xFF1E3A8A),
                    strokeWidth: 5,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  ...tracking.stops.map(
                    (s) => Marker(
                      point: s.position,
                      width: 28,
                      height: 28,
                      child: const Icon(
                        Icons.location_on,
                        color: Color(0xFFF59E0B),
                      ),
                    ),
                  ),
                  Marker(
                    point: tracking.busPosition,
                    width: 64,
                    height: 64,
                    child: Transform.rotate(
                      angle: 0.5,
                      child: const Icon(
                        Icons.directions_bus,
                        color: Color(0xFF16A34A),
                        size: 36,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 12,
            child: Card(
              child: ListTile(
                title: Text(
                  'Speed ${tracking.kmh.toStringAsFixed(0)} km/h • Next ${tracking.nextStop}',
                ),
                subtitle: Text(
                  'ETA ${tracking.etaToNextMinutes} mins • $status',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.gps_fixed),
                  onPressed: () {},
                  tooltip: 'Focus on bus',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
