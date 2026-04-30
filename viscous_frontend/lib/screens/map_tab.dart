import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';

// ─── Constants ────────────────────────────────────────────────────────────
const Color _kCyan    = Color(0xFF00D4FF);
const Color _kAmber   = Color(0xFFFFB930);
const Color _kGreen   = Color(0xFF00E676);

class MapTab extends ConsumerStatefulWidget {
  const MapTab({super.key});

  @override
  ConsumerState<MapTab> createState() => _MapTabState();
}

class _MapTabState extends ConsumerState<MapTab> {
  late final MapController _mapController;
  Timer? _mapFollowDebounce;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapFollowDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _showBusDetails(TrackingState t) {
    final theme = Theme.of(context);
    final dirLabel = t.direction == -1 ? 'Return' : 'Forward';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bus details',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 14),
                _BusDetailRow(label: 'Bus ID', value: t.routeMeta?.busId ?? '—'),
                _BusDetailRow(label: 'Route', value: t.routeMeta?.routeNumber ?? '—'),
                _BusDetailRow(
                    label: 'Path',
                    value:
                        '${t.routeMeta?.from ?? "—"} → ${t.routeMeta?.to ?? "—"}'),
                _BusDetailRow(
                    label: 'Speed',
                    value: '${t.kmh.toStringAsFixed(1)} km/h (app estimate)'),
                _BusDetailRow(
                    label: 'Status',
                    value: t.isBusRunning ? 'Running' : 'Stopped / idle'),
                _BusDetailRow(label: 'Direction', value: dirLabel),
                _BusDetailRow(label: 'Next stop', value: t.nextStop),
                _BusDetailRow(label: 'GPS', value: t.isGpsStale ? 'Stale' : 'Live'),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(trackingProvider);
    final theme    = Theme.of(context);
    final isDark   = theme.brightness == Brightness.dark;
    final textDim  = isDark ? const Color(0xFF5A6A90) : const Color(0xFF64748B);
    final cardBorder =
        isDark ? theme.dividerColor.withOpacity(0.12) : const Color(0xFFCBD5E1);

    ref.listen(trackingProvider.select((s) => s.busPosition), (prev, next) {
      if (next.latitude == 0 && next.longitude == 0) return;
      _mapFollowDebounce?.cancel();
      _mapFollowDebounce = Timer(const Duration(milliseconds: 320), () {
        if (!mounted) return;
        _mapController.move(next, _mapController.camera.zoom);
      });
    });

    final String status = tracking.routeCompleted
        ? 'Route complete'
        : !tracking.routeStarted
            ? 'Waiting for route start'
            : tracking.isGpsStale
                ? 'GPS stale — last known position'
                : 'Live tracking';

    final Color statusColor = tracking.routeCompleted
        ? _kAmber
        : !tracking.routeStarted
            ? textDim
            : tracking.isGpsStale
                ? _kAmber
                : _kGreen;

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        return RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () => ref.read(trackingProvider.notifier).refreshTracking(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: h,
              child: Stack(
      children: [
        // ── Full-screen map ───────────────────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: tracking.busPosition.latitude == 0 ? const LatLng(21.1458, 79.0882) : tracking.busPosition,
            initialZoom: 14,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.viscous_frontend',
            ),
            // Removed PolylineLayer to hide route highlights
            MarkerLayer(
              markers: [
                // Stop markers
                ...tracking.stops.map(
                  (s) => Marker(
                    point: s.position,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ),
                // Bus marker (tap for details; speed from client-side estimate in app state)
                Marker(
                  point: tracking.busPosition,
                  width: 56,
                  height: 62,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _showBusDetails(tracking),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        _PulsingBusMarker(isMoving: tracking.isBusRunning),
                        Positioned(
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _kCyan.withOpacity(0.35)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.12),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: Text(
                              '${tracking.kmh.round()} km/h',
                              style: TextStyle(
                                color: isDark ? _kCyan : const Color(0xFF0369A1),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // ── Top overlay card ──────────────────────────────────────────────
        SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(isDark ? 0.95 : 1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.45 : 0.08),
                        blurRadius: isDark ? 20 : 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Speed chip
                      _InfoChip(
                        icon: Icons.speed_rounded,
                        value: '${tracking.kmh.toStringAsFixed(1)} km/h',
                        color: _kCyan,
                      ),
                      const SizedBox(width: 10),
                      // ETA chip
                      _InfoChip(
                        icon: Icons.schedule_rounded,
                        value: '${tracking.etaToNextMinutes} min eta',
                        color: _kAmber,
                      ),
                      const Spacer(),
                      // Status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: statusColor.withOpacity(0.4)),
                        ),
                        child: Text(status,
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ),
              // Next stop banner
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(isDark ? 0.9 : 1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? _kCyan.withOpacity(0.2) : const Color(0xFF93C5FD),
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.location_on_rounded, color: _kCyan, size: 14),
                    const SizedBox(width: 8),
                    Text('Next stop:  ', style: TextStyle(color: textDim, fontSize: 11)),
                    Text(tracking.nextStop,
                        style: TextStyle(
                          color: theme.textTheme.bodyLarge?.color, 
                          fontSize: 12, 
                          fontWeight: FontWeight.w700
                        )),
                  ]),
                ),
              ),
            ],
          ),
        ),

        // ── Zoom Controls ────────────────────────────────────────────────
        Positioned(
          bottom: 170,
          right: 16,
          child: Column(
            children: [
              _MapControlButton(
                icon: Icons.add_rounded,
                onTap: () {
                  _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1);
                },
              ),
              const SizedBox(height: 8),
              _MapControlButton(
                icon: Icons.remove_rounded,
                onTap: () {
                  _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1);
                },
              ),
            ],
          ),
        ),

        // ── GPS focus FAB ─────────────────────────────────────────────────
        Positioned(
          bottom: 110,
          right: 16,
          child: _MapControlButton(
            icon: Icons.gps_fixed_rounded,
            onTap: () {
              if (tracking.busPosition.latitude != 0) {
                _mapController.move(tracking.busPosition, 16);
              }
            },
          ),
        ),
      ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BusDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _BusDetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dim = theme.brightness == Brightness.dark
        ? const Color(0xFF5A6A90)
        : const Color(0xFF64748B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(label, style: TextStyle(color: dim, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapControlButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface,
          border: Border.all(color: _kCyan.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(color: _kCyan.withOpacity(0.2), blurRadius: 12),
          ],
        ),
        child: Icon(icon, color: _kCyan, size: 20),
      ),
    );
  }
}

class _PulsingBusMarker extends StatefulWidget {
  final bool isMoving;
  const _PulsingBusMarker({required this.isMoving});
  @override
  State<_PulsingBusMarker> createState() => _PulsingBusMarkerState();
}

class _PulsingBusMarkerState extends State<_PulsingBusMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl   = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _scale  = Tween<double>(begin: 0.85, end: 1.15).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isMoving)
              Transform.scale(
                scale: _scale.value,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kGreen.withOpacity(0.12 * _ctrl.value),
                  ),
                ),
              ),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.scaffoldBackgroundColor,
                border: Border.all(color: _kGreen, width: 2.5),
                boxShadow: [BoxShadow(color: _kGreen.withOpacity(0.6), blurRadius: 12 * (_ctrl.value + 0.3))],
              ),
              child: const Icon(Icons.directions_bus_rounded, color: _kGreen, size: 18),
            ),
          ],
        );
      },
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _InfoChip({required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 5),
      Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    ]);
  }
}
