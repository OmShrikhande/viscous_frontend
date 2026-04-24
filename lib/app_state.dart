import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

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
    required this.lastUpdated,
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
  final DateTime lastUpdated;

  String get currentStop =>
      stops[currentStopIndex.clamp(0, stops.length - 1)].name;
  String get nextStop => stops[nextStopIndex.clamp(0, stops.length - 1)].name;
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
    DateTime? lastUpdated,
  }) {
    return TrackingState(
      stops: stops,
      currentStopIndex: currentStopIndex ?? this.currentStopIndex,
      nextStopIndex: nextStopIndex ?? this.nextStopIndex,
      busPosition: busPosition ?? this.busPosition,
      kmh: kmh ?? this.kmh,
      delayMinutes: delayMinutes ?? this.delayMinutes,
      routeStarted: routeStarted ?? this.routeStarted,
      routeCompleted: routeCompleted ?? this.routeCompleted,
      isGpsStale: isGpsStale ?? this.isGpsStale,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class TrackingController extends StateNotifier<TrackingState> {
  TrackingController() : super(_seedState()) {
    _startSimulation();
  }

  Timer? _timer;
  int _tick = 0;

  static TrackingState _seedState() {
    final stops = <BusStop>[
      const BusStop(name: 'Central School', position: LatLng(12.9716, 77.5946)),
      const BusStop(name: 'Lake View Stop', position: LatLng(12.9738, 77.5986)),
      const BusStop(name: 'Hill Road Stop', position: LatLng(12.9776, 77.6020)),
      const BusStop(
        name: 'Green Park Stop',
        position: LatLng(12.9801, 77.6071),
      ),
      const BusStop(
        name: 'Maple Residency',
        position: LatLng(12.9847, 77.6124),
      ),
    ];
    return TrackingState(
      stops: stops,
      currentStopIndex: 0,
      nextStopIndex: 1,
      busPosition: stops.first.position,
      kmh: 27,
      delayMinutes: 0,
      routeStarted: false,
      routeCompleted: false,
      isGpsStale: false,
      lastUpdated: DateTime.now(),
    );
  }

  void _startSimulation() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _tick++;
      if (_tick == 1) {
        state = state.copyWith(routeStarted: true, lastUpdated: DateTime.now());
        return;
      }
      if (state.routeCompleted) return;

      final newCurrent = (state.currentStopIndex + 1).clamp(
        0,
        state.stops.length - 1,
      );
      final newNext = (newCurrent + 1).clamp(0, state.stops.length - 1);
      final finished = newCurrent >= state.stops.length - 1;

      state = state.copyWith(
        currentStopIndex: newCurrent,
        nextStopIndex: newNext,
        busPosition: state.stops[newCurrent].position,
        delayMinutes: _tick % 3 == 0 ? 2 : 0,
        kmh: finished ? 0 : 24 + (_tick % 10),
        routeCompleted: finished,
        isGpsStale: _tick % 6 == 0,
        lastUpdated: DateTime.now(),
      );
    });
  }

  void markRouteDeviation() {
    state = state.copyWith(delayMinutes: 7, lastUpdated: DateTime.now());
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
