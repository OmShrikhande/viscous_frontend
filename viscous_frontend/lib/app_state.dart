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
    required this.delayMinutes,
    required this.routeStarted,
    required this.routeCompleted,
    required this.isGpsStale,
    required this.isBusRunning,
    required this.busStatus,
    required this.direction,
    required this.roundsCompleted,
    required this.currentDisplayIndex,
    required this.lastUpdated,
    this.routeMeta,
    this.progressToNextStop = 0.0,
  });

  final List<BusStop> stops;
  final int currentStopIndex;
  final int nextStopIndex;
  final LatLng busPosition;
  final double kmh;
  final int delayMinutes;
  final bool routeStarted;
  final bool routeCompleted;
  final bool isGpsStale;
  final bool isBusRunning;
  final String busStatus;
  final int direction;
  final int roundsCompleted;
  final int currentDisplayIndex;
  final DateTime lastUpdated;
  final RouteMeta? routeMeta;
  final double progressToNextStop;

  String get currentStop =>
      stops.isEmpty ? 'Loading...' : stops[currentStopIndex.clamp(0, stops.length - 1)].name;
  String get nextStop => stops.isEmpty ? '...' : stops[nextStopIndex.clamp(0, stops.length - 1)].name;
  int get etaToNextMinutes =>
      routeCompleted ? 0 : (delayMinutes + 3).clamp(1, 30);
  int get completionPercent {
    if (stops.isEmpty) return 0;
    return ((currentStopIndex + 1) / stops.length * 100).round().clamp(0, 100);
  }

  TrackingState copyWith({
    int? currentStopIndex,
    int? nextStopIndex,
    LatLng? busPosition,
    double? kmh,
    int? delayMinutes,
    bool? routeStarted,
    bool? routeCompleted,
    bool? isGpsStale,
    bool? isBusRunning,
    String? busStatus,
    int? direction,
    int? roundsCompleted,
    int? currentDisplayIndex,
    DateTime? lastUpdated,
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
      delayMinutes: delayMinutes ?? this.delayMinutes,
      routeStarted: routeStarted ?? this.routeStarted,
      routeCompleted: routeCompleted ?? this.routeCompleted,
      isGpsStale: isGpsStale ?? this.isGpsStale,
      isBusRunning: isBusRunning ?? this.isBusRunning,
      busStatus: busStatus ?? this.busStatus,
      direction: direction ?? this.direction,
      roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      currentDisplayIndex: currentDisplayIndex ?? this.currentDisplayIndex,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      routeMeta: routeMeta ?? this.routeMeta,
      progressToNextStop: progressToNextStop ?? this.progressToNextStop,
    );
  }
}

class TrackingController extends StateNotifier<TrackingState> {
  final LocationService _locationService = LocationService();

  TrackingController() : super(_seedState()) {
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      await _refreshFromBackend();
      _startPolling();
    } catch (e) {
      debugPrint("Error initializing route: $e");
    }
  }

  Timer? _timer;
  bool _inFlight = false;

  static TrackingState _seedState() {
    final stops = <BusStop>[];
    return TrackingState(
      stops: stops,
      currentStopIndex: 0,
      nextStopIndex: 0,
      busPosition: const LatLng(0, 0),
      kmh: 27,
      delayMinutes: 0,
      routeStarted: false,
      routeCompleted: false,
      isGpsStale: false,
      isBusRunning: false,
      busStatus: "stop",
      direction: 1,
      roundsCompleted: 0,
      currentDisplayIndex: 0,
      lastUpdated: DateTime.now(),
      routeMeta: null,
    );
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      _refreshFromBackend();
    });
  }

  Future<void> _refreshFromBackend() async {
    if (_inFlight) return;
    _inFlight = true;
    try {
      final data = await _locationService.getBusLocation();
      final routeStopsRaw = (data['routeStops'] as List? ?? []);
      final orderedStopsRaw = (data['orderedStops'] as List? ?? routeStopsRaw);
      final stops = routeStopsRaw.map((s) {
        final coords = (s['coordinates'] as List?) ??
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
        final coords = (s['coordinates'] as List?) ??
            [s['latitude'] ?? 0.0, s['longitude'] ?? 0.0];
        return BusStop(
          name: (s['name'] ?? '').toString(),
          position: LatLng(
            (coords[0] as num).toDouble(),
            (coords[1] as num).toDouble(),
          ),
        );
      }).toList();

      final latitude = (data['latitude'] as num?)?.toDouble() ?? state.busPosition.latitude;
      final longitude = (data['longitude'] as num?)?.toDouble() ?? state.busPosition.longitude;
      final currentStopIndex = (data['currentStopIndex'] as num?)?.toInt() ?? 0;
      final nextStopIndex = (data['nextStopIndex'] as num?)?.toInt() ??
          (currentStopIndex + 1).clamp(0, orderedStops.isEmpty ? 0 : orderedStops.length - 1);
      final status = (data['status'] ?? 'stop').toString().toLowerCase();
      final running = status == 'running';
      final direction = (data['direction'] as num?)?.toInt() == -1 ? -1 : 1;
      final speedKmh = (data['speedKmh'] as num?)?.toDouble() ?? state.kmh;
      final displayIndex = (data['currentDisplayIndex'] as num?)?.toInt() ??
          currentStopIndex.clamp(0, orderedStops.isEmpty ? 0 : orderedStops.length - 1);
      final routeMeta = data['routeMeta'] is Map<String, dynamic>
          ? RouteMeta.fromJson(data['routeMeta'])
          : state.routeMeta;

      state = state.copyWith(
        stops: orderedStops.isEmpty ? (stops.isEmpty ? state.stops : stops) : orderedStops,
        currentStopIndex: currentStopIndex.clamp(0, stops.isEmpty ? 0 : stops.length - 1),
        nextStopIndex: nextStopIndex.clamp(0, (orderedStops.isEmpty ? stops : orderedStops).isEmpty ? 0 : (orderedStops.isEmpty ? stops : orderedStops).length - 1),
        busPosition: LatLng(latitude, longitude),
        kmh: speedKmh,
        routeStarted: data['updatedAt'] != null,
        routeCompleted: false,
        isGpsStale: !running,
        isBusRunning: running,
        busStatus: status,
        direction: direction,
        roundsCompleted: (data['roundsCompleted'] as num?)?.toInt() ?? state.roundsCompleted,
        currentDisplayIndex: displayIndex.clamp(0, (orderedStops.isEmpty ? stops : orderedStops).isEmpty ? 0 : (orderedStops.isEmpty ? stops : orderedStops).length - 1),
        routeMeta: routeMeta,
        progressToNextStop: 0.0,
        lastUpdated: DateTime.now(),
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

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

