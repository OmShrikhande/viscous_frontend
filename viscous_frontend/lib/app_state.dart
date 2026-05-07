import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'services/location_service.dart';

class RouteMeta {
  const RouteMeta({
    required this.id,
    required this.routeNumber,
    required this.busId,
    required this.from,
    required this.to,
    required this.college,
  });

  final String id;
  final String routeNumber;
  final String busId;
  final String from;
  final String to;
  final String college;

  factory RouteMeta.fromJson(Map<String, dynamic> json) {
    return RouteMeta(
      id: (json['id'] ?? '').toString(),
      routeNumber: (json['routeNumber'] ?? '').toString(),
      busId: (json['busId'] ?? '').toString(),
      from: (json['from'] ?? '').toString(),
      to: (json['to'] ?? '').toString(),
      college: (json['college'] ?? '').toString(),
    );
  }
}

class BusStop {
  const BusStop({required this.name, required this.position});

  final String name;
  final LatLng position;
}

class TrackingState {
  const TrackingState({
    required this.stops,
    required this.currentStopIndex,
    required this.nextStopIndex,
    required this.busPosition,
    required this.kmh,
    required this.etaSeconds,
    required this.distanceToNextMeters,
    required this.routeStarted,
    required this.routeCompleted,
    required this.isGpsStale,
    required this.isBusRunning,
    required this.busStatus,
    required this.direction,
    required this.roundsCompleted,
    required this.currentDisplayIndex,
    required this.lastUpdated,
    required this.confidenceScore,
    required this.confidenceLevel,
    this.routeMeta,
    this.progressToNextStop = 0.0,
  });

  final List<BusStop> stops;
  final int currentStopIndex;
  final int nextStopIndex;
  final LatLng busPosition;
  final double kmh;

  /// ETA from backend (seconds). Computed as remaining-distance / smoothed-speed.
  /// Falls back to `null`-ish-zero only when the bus is at the next stop.
  final int etaSeconds;
  final int distanceToNextMeters;
  final bool routeStarted;
  final bool routeCompleted;
  final bool isGpsStale;
  final bool isBusRunning;
  final String busStatus;
  final int direction;
  final int roundsCompleted;
  final int currentDisplayIndex;
  final DateTime lastUpdated;
  final int confidenceScore;
  final String confidenceLevel;
  final RouteMeta? routeMeta;

  /// Animated 0.0..1.0 fraction of progress along the segment between the
  /// current and next stop. Updated by a client-side animation tick so the bus
  /// glides instead of teleporting between snapshots.
  final double progressToNextStop;

  String get currentStop => stops.isEmpty
      ? 'Loading...'
      : stops[currentStopIndex.clamp(0, stops.length - 1)].name;
  String get nextStop => stops.isEmpty
      ? '...'
      : stops[nextStopIndex.clamp(0, stops.length - 1)].name;

  /// Display ETA (minutes), rounded up so we never show "0 min" while moving.
  int get etaToNextMinutes {
    if (routeCompleted) return 0;
    if (etaSeconds <= 0) {
      // No backend value yet (or bus is stationary at the stop).
      return isBusRunning ? 1 : 0;
    }
    return (etaSeconds / 60).ceil().clamp(1, 99);
  }

  /// Friendly label like "2 min" / "45 sec" for compact displays.
  String get etaLabel {
    if (routeCompleted) return 'Arrived';
    if (etaSeconds <= 0) return isBusRunning ? '<1 min' : '—';
    if (etaSeconds < 60) return '${etaSeconds}s';
    final minutes = (etaSeconds / 60).round();
    return '${minutes.clamp(1, 99)} min';
  }

  int get completionPercent {
    if (stops.isEmpty) return 0;
    return ((currentStopIndex + 1) / stops.length * 100).round().clamp(0, 100);
  }

  TrackingState copyWith({
    int? currentStopIndex,
    int? nextStopIndex,
    LatLng? busPosition,
    double? kmh,
    int? etaSeconds,
    int? distanceToNextMeters,
    bool? routeStarted,
    bool? routeCompleted,
    bool? isGpsStale,
    bool? isBusRunning,
    String? busStatus,
    int? direction,
    int? roundsCompleted,
    int? currentDisplayIndex,
    DateTime? lastUpdated,
    int? confidenceScore,
    String? confidenceLevel,
    RouteMeta? routeMeta,
    List<BusStop>? stops,
    double? progressToNextStop,
  }) {
    return TrackingState(
      stops: stops ?? this.stops,
      currentStopIndex: currentStopIndex ?? this.currentStopIndex,
      nextStopIndex: nextStopIndex ?? this.nextStopIndex,
      busPosition: busPosition ?? this.busPosition,
      kmh: kmh ?? this.kmh,
      etaSeconds: etaSeconds ?? this.etaSeconds,
      distanceToNextMeters: distanceToNextMeters ?? this.distanceToNextMeters,
      routeStarted: routeStarted ?? this.routeStarted,
      routeCompleted: routeCompleted ?? this.routeCompleted,
      isGpsStale: isGpsStale ?? this.isGpsStale,
      isBusRunning: isBusRunning ?? this.isBusRunning,
      busStatus: busStatus ?? this.busStatus,
      direction: direction ?? this.direction,
      roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      currentDisplayIndex: currentDisplayIndex ?? this.currentDisplayIndex,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
      routeMeta: routeMeta ?? this.routeMeta,
      progressToNextStop: progressToNextStop ?? this.progressToNextStop,
    );
  }
}

class TrackingController extends StateNotifier<TrackingState> {
  final LocationService _locationService = LocationService();
  static const Distance _distance = Distance();
  // Match the backend's 12s sync cadence. With backend snapshot caching at 10s,
  // this means at most ~1.2 reads/min/user instead of the previous ~5/min.
  static const Duration _pollInterval = Duration(seconds: 15);
  // Smooth-glide animation: 60 fps would be wasteful here; 8 ticks/sec is plenty.
  static const Duration _animTickInterval = Duration(milliseconds: 125);

  TrackingController() : super(_seedState()) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _refreshFromBackend();
      _startPolling();
      _startAnimationTicker();
    } catch (e) {
      debugPrint("Error initializing route: $e");
    }
  }

  Timer? _timer;
  Timer? _animTimer;
  bool _inFlight = false;
  LatLng? _prevGeo;
  DateTime? _prevGeoTime;
  double? _clientSmoothedKmh;
  int _geoSamples = 0;
  DateTime? _lastUserRefreshAt;

  /// Wall-clock time when the last backend snapshot landed; used to advance the
  /// `progressToNextStop` smoothly between snapshots so the bus glides instead
  /// of teleporting from stop to stop.
  DateTime? _lastSnapshotAt;

  /// Estimated time-of-arrival at the next stop (wall clock). Updated whenever
  /// we get a fresh backend snapshot; used to interpolate progress 0..1.
  DateTime? _segmentEtaAt;
  int _animSegmentStopIndex = -1;

  static TrackingState _seedState() {
    final stops = <BusStop>[];
    return TrackingState(
      stops: stops,
      currentStopIndex: 0,
      nextStopIndex: 0,
      busPosition: const LatLng(0, 0),
      kmh: 0,
      etaSeconds: 0,
      distanceToNextMeters: 0,
      routeStarted: false,
      routeCompleted: false,
      isGpsStale: false,
      isBusRunning: false,
      busStatus: "stop",
      direction: 1,
      roundsCompleted: 0,
      currentDisplayIndex: 0,
      lastUpdated: DateTime.now(),
      confidenceScore: 0,
      confidenceLevel: "unknown",
      routeMeta: null,
    );
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) {
      _refreshFromBackend();
    });
  }

  /// Drives the `progressToNextStop` value forward in small steps so the bus
  /// icon on the timeline animates smoothly rather than jumping when a new
  /// backend snapshot arrives.
  void _startAnimationTicker() {
    _animTimer?.cancel();
    _animTimer = Timer.periodic(_animTickInterval, (_) {
      if (state.stops.isEmpty || !state.isBusRunning) return;

      final now = DateTime.now();
      final eta = _segmentEtaAt;
      final segStart = _lastSnapshotAt;
      if (eta == null || segStart == null) return;

      final totalMs = eta.difference(segStart).inMilliseconds;
      if (totalMs <= 0) return;
      final elapsedMs = now.difference(segStart).inMilliseconds;
      // Cap at 0.97 — never animate past "almost there"; the next snapshot
      // should snap us to the new stop. Avoids overshoot if backend is late.
      final progress = (elapsedMs / totalMs).clamp(0.0, 0.97);

      if ((progress - state.progressToNextStop).abs() < 0.005) return;
      state = state.copyWith(progressToNextStop: progress);
    });
  }

  /// Pull-to-refresh / manual sync. Throttled so rapid gestures do not stack API calls.
  Future<void> refreshTracking() async {
    final now = DateTime.now();
    if (_lastUserRefreshAt != null &&
        now.difference(_lastUserRefreshAt!) <
            const Duration(milliseconds: 550)) {
      return;
    }
    _lastUserRefreshAt = now;
    await _refreshFromBackend();
  }

  double _computeClientSpeedKmh(
    LatLng newPos,
    DateTime now,
    double? apiSpeedKmh,
  ) {
    if (_prevGeo != null && _prevGeoTime != null) {
      final dtSec = now.difference(_prevGeoTime!).inMilliseconds / 1000.0;
      if (dtSec >= 0.35 && dtSec < 180) {
        final meters = _distance(_prevGeo!, newPos).toDouble();
        if (meters >= 0 && meters < 3_000) {
          final instant = (meters / dtSec) * 3.6;
          if (instant.isFinite && instant <= 130) {
            _clientSmoothedKmh = _clientSmoothedKmh == null
                ? instant
                : _clientSmoothedKmh! * 0.62 + instant * 0.38;
            _geoSamples++;
          }
        }
      }
    }
    _prevGeo = newPos;
    _prevGeoTime = now;

    if (_geoSamples >= 2 && _clientSmoothedKmh != null) {
      return _clientSmoothedKmh!.clamp(0.0, 130.0);
    }
    return (apiSpeedKmh ?? state.kmh).clamp(0.0, 130.0);
  }

  Future<void> _refreshFromBackend() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final data = await _locationService.getBusLocation();
      final routeStopsRaw = (data['routeStops'] as List? ?? []);
      final orderedStopsRaw = (data['orderedStops'] as List? ?? routeStopsRaw);
      final stops = routeStopsRaw.map((s) {
        final coords =
            (s['coordinates'] as List?) ??
            [s['latitude'] ?? 0.0, s['longitude'] ?? 0.0];
        return BusStop(
          name: (s['name'] ?? '').toString(),
          position: LatLng(
            (coords[0] as num).toDouble(),
            (coords[1] as num).toDouble(),
          ),
        );
      }).toList();
      final orderedStops = orderedStopsRaw.map((s) {
        final coords =
            (s['coordinates'] as List?) ??
            [s['latitude'] ?? 0.0, s['longitude'] ?? 0.0];
        return BusStop(
          name: (s['name'] ?? '').toString(),
          position: LatLng(
            (coords[0] as num).toDouble(),
            (coords[1] as num).toDouble(),
          ),
        );
      }).toList();

      final latitude =
          (data['latitude'] as num?)?.toDouble() ?? state.busPosition.latitude;
      final longitude =
          (data['longitude'] as num?)?.toDouble() ??
          state.busPosition.longitude;
      final currentStopIndex = (data['currentStopIndex'] as num?)?.toInt() ?? 0;
      final nextStopIndex =
          (data['nextStopIndex'] as num?)?.toInt() ??
          (currentStopIndex + 1).clamp(
            0,
            orderedStops.isEmpty ? 0 : orderedStops.length - 1,
          );
      final status = (data['status'] ?? 'stop').toString().toLowerCase();
      final backendUpdatedAtRaw = (data['updatedAt'] ?? '').toString();
      final backendUpdatedAt = DateTime.tryParse(backendUpdatedAtRaw);
      final samePositionAsPrevious =
          state.busPosition.latitude == latitude &&
          state.busPosition.longitude == longitude;
      final backendFreshness = backendUpdatedAt == null
          ? Duration.zero
          : DateTime.now().difference(backendUpdatedAt);
      var running = status == 'running';
      if (running &&
          samePositionAsPrevious &&
          backendFreshness > const Duration(seconds: 60)) {
        running = false;
      }
      final direction = (data['direction'] as num?)?.toInt() == -1 ? -1 : 1;
      final apiSpeedKmh = (data['speedKmh'] as num?)?.toDouble();
      final newPos = LatLng(latitude, longitude);
      final now = DateTime.now();
      final speedKmh = _computeClientSpeedKmh(newPos, now, apiSpeedKmh);
      final displayIndex =
          (data['currentDisplayIndex'] as num?)?.toInt() ??
          currentStopIndex.clamp(
            0,
            orderedStops.isEmpty ? 0 : orderedStops.length - 1,
          );
      final routeMeta = data['routeMeta'] is Map<String, dynamic>
          ? RouteMeta.fromJson(data['routeMeta'])
          : state.routeMeta;
      final etaSeconds = (data['etaToNextSeconds'] as num?)?.toInt() ?? 0;
      final distanceToNextMeters =
          (data['distanceToNextStopMeters'] as num?)?.toInt() ?? 0;

      // Re-arm smooth animation tween whenever the bus has advanced to a new
      // stop OR we've never armed it yet. We treat each (currentStopIndex,
      // nextStopIndex) pair as one segment and animate progress 0..1 across it.
      final segmentChanged =
          _animSegmentStopIndex != currentStopIndex ||
          _lastSnapshotAt == null;
      if (segmentChanged) {
        _animSegmentStopIndex = currentStopIndex;
        _lastSnapshotAt = now;
        _segmentEtaAt = etaSeconds > 0
            ? now.add(Duration(seconds: etaSeconds))
            // No ETA yet (e.g. just stationary at stop) → use poll interval
            // as a sane fallback so the bus doesn't sit perfectly still.
            : now.add(_pollInterval);
      } else {
        // Same segment, just refresh ETA target so the glide rate self-corrects
        // when GPS slows/speeds up between snapshots.
        _segmentEtaAt = etaSeconds > 0
            ? now.add(Duration(seconds: etaSeconds))
            : _segmentEtaAt;
      }

      // Compute initial progress for this snapshot. If we just landed on a new
      // stop, restart at 0; otherwise preserve smoothly-advancing client value.
      final initialProgress = segmentChanged ? 0.0 : state.progressToNextStop;

      state = state.copyWith(
        stops: orderedStops.isEmpty
            ? (stops.isEmpty ? state.stops : stops)
            : orderedStops,
        currentStopIndex: currentStopIndex.clamp(
          0,
          stops.isEmpty ? 0 : stops.length - 1,
        ),
        nextStopIndex: nextStopIndex.clamp(
          0,
          (orderedStops.isEmpty ? stops : orderedStops).isEmpty
              ? 0
              : (orderedStops.isEmpty ? stops : orderedStops).length - 1,
        ),
        busPosition: newPos,
        kmh: speedKmh,
        etaSeconds: etaSeconds,
        distanceToNextMeters: distanceToNextMeters,
        routeStarted: data['updatedAt'] != null,
        routeCompleted: false,
        isGpsStale: !running,
        isBusRunning: running,
        busStatus: status,
        direction: direction,
        roundsCompleted:
            (data['roundsCompleted'] as num?)?.toInt() ?? state.roundsCompleted,
        currentDisplayIndex: displayIndex.clamp(
          0,
          (orderedStops.isEmpty ? stops : orderedStops).isEmpty
              ? 0
              : (orderedStops.isEmpty ? stops : orderedStops).length - 1,
        ),
        routeMeta: routeMeta,
        progressToNextStop: initialProgress,
        lastUpdated: DateTime.now(),
        confidenceScore:
            (data['confidenceScore'] as num?)?.toInt() ?? state.confidenceScore,
        confidenceLevel: (data['confidenceLevel'] ?? state.confidenceLevel)
            .toString(),
      );
    } catch (error) {
      debugPrint('Tracking refresh failed: $error');
    } finally {
      _inFlight = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animTimer?.cancel();
    super.dispose();
  }
}

final authStateProvider = StateProvider<bool>((ref) => false);
final currentTabProvider = StateProvider<int>((ref) => 0);
final trackingProvider =
    StateNotifierProvider<TrackingController, TrackingState>(
      (ref) => TrackingController(),
    );

final homeMiniTabProvider = StateProvider<int>((ref) => 0);

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
