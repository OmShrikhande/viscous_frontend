import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../app_state.dart';

// ─── Theme-resolved helpers (same convention as home_tab) ─────────────────────
Color _amber(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark
    ? const Color(0xFFFFB930)
    : const Color(0xFFD97706);
Color _green(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark
    ? const Color(0xFF00E676)
    : const Color(0xFF059669);
Color _textDim(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark
    ? const Color(0xFF5A6A90)
    : const Color(0xFF64748B);

// Stop marker red — the user explicitly asked for red instead of light blue.
const Color _stopRed = Color(0xFFE11D48);
const Color _stopRedDark = Color(0xFFB91C1C);

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.directions_bus_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Bus Details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _BusDetailRow(
                  label: 'Bus ID',
                  value: t.routeMeta?.busId ?? '—',
                ),
                _BusDetailRow(
                  label: 'Route',
                  value: t.routeMeta?.routeNumber ?? '—',
                ),
                _BusDetailRow(
                  label: 'Path',
                  value:
                      '${t.routeMeta?.from ?? "—"} → ${t.routeMeta?.to ?? "—"}',
                ),
                _BusDetailRow(
                  label: 'Speed',
                  value: '${t.kmh.toStringAsFixed(1)} km/h (app estimate)',
                ),
                _BusDetailRow(
                  label: 'Status',
                  value: t.isBusRunning ? 'Running' : 'Stopped / Idle',
                ),
                _BusDetailRow(label: 'Direction', value: dirLabel),
                _BusDetailRow(label: 'Next Stop', value: t.nextStop),
                _BusDetailRow(
                  label: 'GPS',
                  value: t.isGpsStale ? 'Stale ⚠' : 'Live ✓',
                ),
                _BusDetailRow(
                  label: 'Confidence',
                  value:
                      '${t.confidenceScore}% (${t.confidenceLevel.toUpperCase()})',
                ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    ref.listen(trackingProvider.select((s) => s.busPosition), (prev, next) {
      if (next.latitude == 0 && next.longitude == 0) return;
      _mapFollowDebounce?.cancel();
      _mapFollowDebounce = Timer(const Duration(milliseconds: 320), () {
        if (!mounted) return;
        _mapController.move(next, _mapController.camera.zoom);
      });
    });

    final String status = tracking.routeCompleted
        ? 'Route Complete'
        : !tracking.routeStarted
        ? 'Waiting for Route'
        : tracking.isGpsStale
        ? 'GPS Stale'
        : 'Live Tracking';

    final Color statusColor = tracking.routeCompleted
        ? _amber(context)
        : !tracking.routeStarted
        ? _textDim(context)
        : tracking.isGpsStale
        ? _amber(context)
        : _green(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : MediaQuery.sizeOf(context).height;
        return RefreshIndicator(
          color: theme.colorScheme.primary,
          onRefresh: () =>
              ref.read(trackingProvider.notifier).refreshTracking(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: h,
              child: Stack(
                children: [
                  // ── Full-screen map ─────────────────────────────────────
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: tracking.busPosition.latitude == 0
                          ? const LatLng(21.1458, 79.0882)
                          : tracking.busPosition,
                      initialZoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.viscous.busTracker',
                      ),
                      MarkerLayer(
                        markers: [
                          // Stop markers — themed location pins
                          ...tracking.stops.map(
                            (s) => Marker(
                              point: s.position,
                              width: 44,
                              height: 44,
                              child: _StopPin(isDark: isDark),
                            ),
                          ),
                          // Bus marker (speed is shown in the bottom speed bar)
                          Marker(
                            point: tracking.busPosition,
                            width: 60,
                            height: 60,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _showBusDetails(tracking),
                              child: _PulsingBusMarker(
                                isMoving: tracking.isBusRunning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // ── Top info overlay ────────────────────────────────────
                  SafeArea(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                          child: _MapCard(
                            child: Row(
                              children: [
                                _InfoChip(
                                  icon: Icons.schedule_rounded,
                                  value: tracking.etaLabel,
                                  color: _amber(context),
                                ),
                                const SizedBox(width: 12),
                                _InfoChip(
                                  icon: Icons.verified_rounded,
                                  value: '${tracking.confidenceScore}%',
                                  color: tracking.confidenceLevel == 'high'
                                      ? _green(context)
                                      : tracking.confidenceLevel == 'medium'
                                      ? _amber(context)
                                      : _textDim(context),
                                ),
                                const Spacer(),
                                _StatusBadge(
                                  status: status,
                                  color: statusColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                          child: _MapCard(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  color: _stopRed,
                                  size: 15,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Next stop:  ',
                                  style: TextStyle(
                                    color: _textDim(context),
                                    fontSize: 11,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    tracking.nextStop,
                                    style: TextStyle(
                                      color: theme.textTheme.bodyLarge?.color,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (tracking.distanceToNextMeters > 0) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDistance(
                                      tracking.distanceToNextMeters,
                                    ),
                                    style: TextStyle(
                                      color: _textDim(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Map controls ────────────────────────────────────────
                  Positioned(
                    bottom: 200,
                    right: 16,
                    child: Column(
                      children: [
                        _MapControlButton(
                          icon: Icons.add_rounded,
                          onTap: () => _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom + 1,
                          ),
                          theme: theme,
                        ),
                        const SizedBox(height: 8),
                        _MapControlButton(
                          icon: Icons.remove_rounded,
                          onTap: () => _mapController.move(
                            _mapController.camera.center,
                            _mapController.camera.zoom - 1,
                          ),
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 140,
                    right: 16,
                    child: _MapControlButton(
                      icon: Icons.gps_fixed_rounded,
                      onTap: () {
                        if (tracking.busPosition.latitude != 0) {
                          _mapController.move(tracking.busPosition, 16);
                        }
                      },
                      theme: theme,
                    ),
                  ),

                  // ── Bottom speed bar (backend-computed speed) ───────────
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 16,
                    child: _SpeedBottomBar(
                      kmh: tracking.kmh,
                      isMoving: tracking.isBusRunning,
                      etaLabel: tracking.etaLabel,
                      nextStop: tracking.nextStop,
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

String _formatDistance(int meters) {
  if (meters < 1000) return '$meters m';
  final km = meters / 1000;
  return '${km.toStringAsFixed(km >= 10 ? 0 : 1)} km';
}

// ─── Stop pin ─────────────────────────────────────────────────────────────────
class _StopPin extends StatelessWidget {
  final bool isDark;
  const _StopPin({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final pinColor = isDark ? _stopRed : _stopRedDark;
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: pinColor.withValues(alpha: 0.18),
            border: Border.all(
              color: pinColor.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
        ),
        Icon(Icons.location_on_rounded, color: pinColor, size: 28),
      ],
    );
  }
}

// ─── Pulsing bus marker (map) — custom-painted school bus side view ────────────
class _PulsingBusMarker extends StatefulWidget {
  final bool isMoving;
  const _PulsingBusMarker({required this.isMoving});

  @override
  State<_PulsingBusMarker> createState() => _PulsingBusMarkerState();
}

class _PulsingBusMarkerState extends State<_PulsingBusMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (widget.isMoving)
              Transform.scale(
                scale: _pulse.value,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(
                      0xFFF59E0B,
                    ).withValues(alpha: 0.12 * _ctrl.value),
                    border: Border.all(
                      color: const Color(
                        0xFFF59E0B,
                      ).withValues(alpha: 0.3 * _ctrl.value),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            // Shield-shaped bus badge
            CustomPaint(
              painter: _BusSidePainter(anim: _ctrl.value),
              size: const Size(42, 34),
            ),
          ],
        );
      },
    );
  }
}

/// Paints a side-view school bus for the map marker.
class _BusSidePainter extends CustomPainter {
  final double anim;
  const _BusSidePainter({required this.anim});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(2, 3, w - 2, h - 6),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(4),
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Bus body — school bus amber
    final bodyRRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, 2, w, h - 8),
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(4),
      bottomLeft: const Radius.circular(4),
      bottomRight: const Radius.circular(4),
    );
    canvas.drawRRect(bodyRRect, Paint()..color = const Color(0xFFF59E0B));

    // Body highlight stripe
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 2, w * 0.6, h * 0.35),
        topLeft: const Radius.circular(8),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );

    // Safety black stripe
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.45, w, h * 0.1),
      Paint()..color = const Color(0xFF1C1C1E),
    );

    // Windows row
    final winPaint = Paint()
      ..color = const Color(0xFF93C5FD).withValues(alpha: 0.85);
    for (var i = 0; i < 4; i++) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(w * 0.28 + i * (w * 0.17), h * 0.1, w * 0.13, h * 0.28),
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
          bottomLeft: const Radius.circular(1),
          bottomRight: const Radius.circular(1),
        ),
        winPaint,
      );
    }

    // Front cab window
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w * 0.04, h * 0.08, w * 0.18, h * 0.32),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(2),
        bottomLeft: const Radius.circular(1),
        bottomRight: const Radius.circular(1),
      ),
      winPaint,
    );

    // Wheels
    final wheelPaint = Paint()..color = const Color(0xFF1C1C1E);
    final wheelRimPaint = Paint()
      ..color = const Color(0xFF9CA3AF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(w * 0.2, h - 4), 5, wheelPaint);
    canvas.drawCircle(Offset(w * 0.2, h - 4), 3, wheelRimPaint);
    canvas.drawCircle(Offset(w * 0.75, h - 4), 5, wheelPaint);
    canvas.drawCircle(Offset(w * 0.75, h - 4), 3, wheelRimPaint);

    // Headlight (front)
    final hGlow = Paint()
      ..color = const Color(0xFFFEF08A).withValues(alpha: 0.4 + 0.3 * anim)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + 2 * anim);
    canvas.drawCircle(Offset(w * 0.04, h * 0.65), 3.5, hGlow);
    canvas.drawCircle(
      Offset(w * 0.04, h * 0.65),
      2,
      Paint()..color = const Color(0xFFFEF08A),
    );

    // Rear tail light
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(w - 3, h * 0.55, 3, h * 0.18),
        topLeft: const Radius.circular(1),
        topRight: const Radius.circular(1),
        bottomLeft: const Radius.circular(1),
        bottomRight: const Radius.circular(1),
      ),
      Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: 0.7 + 0.3 * anim),
    );

    // Emergency roof lights
    canvas.drawCircle(
      Offset(w * 0.3, 3),
      2.5,
      Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: 0.5 + 0.5 * anim),
    );
    canvas.drawCircle(
      Offset(w * 0.55, 3),
      2.5,
      Paint()
        ..color = const Color(
          0xFF60A5FA,
        ).withValues(alpha: 0.5 + 0.5 * (1 - anim)),
    );
  }

  @override
  bool shouldRepaint(covariant _BusSidePainter old) => old.anim != anim;
}

// ─── Bottom speed bar — prominent, glanceable speed for the driver/parent ───
class _SpeedBottomBar extends StatelessWidget {
  final double kmh;
  final bool isMoving;
  final String etaLabel;
  final String nextStop;

  const _SpeedBottomBar({
    required this.kmh,
    required this.isMoving,
    required this.etaLabel,
    required this.nextStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isMoving ? _green(context) : _textDim(context);
    final speedColor = kmh >= 60
        ? const Color(0xFFEF4444)
        : kmh >= 30
            ? _amber(context)
            : accent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.96 : 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Speed gauge (compact)
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: speedColor.withValues(alpha: 0.12),
              border: Border.all(color: speedColor.withValues(alpha: 0.55), width: 2),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  kmh.round().toString(),
                  style: TextStyle(
                    color: speedColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'km/h',
                  style: TextStyle(
                    color: speedColor.withValues(alpha: 0.85),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Status / ETA / next stop block
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      isMoving
                          ? Icons.directions_bus_filled_rounded
                          : Icons.pause_circle_filled_rounded,
                      color: accent,
                      size: 14,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isMoving ? 'BUS MOVING' : 'STOPPED',
                      style: TextStyle(
                        color: accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _amber(context).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _amber(context).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            color: _amber(context),
                            size: 10,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'ETA $etaLabel',
                            style: TextStyle(
                              color: _amber(context),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Next: $nextStop',
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
class _MapCard extends StatelessWidget {
  final Widget child;
  const _MapCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.95 : 1.0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: isDark ? 20 : 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;
  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;
  const _MapControlButton({
    required this.icon,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surface,
          border: Border.all(color: primary.withValues(alpha: 0.4)),
          boxShadow: [
            BoxShadow(color: primary.withValues(alpha: 0.18), blurRadius: 12),
          ],
        ),
        child: Icon(icon, color: primary, size: 20),
      ),
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
    final dim = _textDim(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
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
