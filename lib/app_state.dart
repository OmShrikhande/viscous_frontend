import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'models/route_response.dart';
import 'services/api_service.dart';
import 'services/storage_service.dart';

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
    this.routeData,
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
  final RouteResponse? routeData;

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
    DateTime? lastUpdated,
    RouteResponse? routeData,
    List<BusStop>? stops,
  }) {
    return TrackingState(
      stops: stops ?? (routeData?.stops.map((s) => BusStop(name: s.name, position: s.position)).toList() ?? this.stops),
      currentStopIndex: currentStopIndex ?? this.currentStopIndex,
      nextStopIndex: nextStopIndex ?? this.nextStopIndex,
      busPosition: busPosition ?? this.busPosition,
      kmh: kmh ?? this.kmh,
      delayMinutes: delayMinutes ?? this.delayMinutes,
      routeStarted: routeStarted ?? this.routeStarted,
      routeCompleted: routeCompleted ?? this.routeCompleted,
      isGpsStale: isGpsStale ?? this.isGpsStale,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      routeData: routeData ?? this.routeData,
    );
  }
}

class TrackingController extends StateNotifier<TrackingState> {
  final StorageService _storage = StorageService();
  final ApiService _api = ApiService();

  TrackingController() : super(_seedState()) {
    _initRoute();
    _startSimulation();
  }

  Future<void> _initRoute() async {
    try {
      print('APP_STATE: Starting route initialization...');
      
      // 1. Check local storage
      var routeData = await _storage.getRouteData();
      
      if (routeData == null) {
        print('APP_STATE: No route data in local storage. Fetching from API...');
        // 2. Fetch from API if not in storage
        final loginData = await _storage.getLoginData();
        final routeNumber = loginData?.user?.route;
        
        print('APP_STATE: User route number: $routeNumber');
        
        if (routeNumber != null) {
          routeData = await _api.getRoute(routeNumber);
          print('APP_STATE: Route data fetched from API. Saving to storage...');
          await _storage.saveRouteData(routeData);
        } else {
          print('APP_STATE: Route number is null in login data!');
        }
      } else {
        print('APP_STATE: Found route data in local storage for route: ${routeData.routeNumber}');
      }

      if (routeData != null) {
        final stops = routeData.stops
            .map((s) => BusStop(name: s.name, position: s.position))
            .toList();
        
        print('APP_STATE: Updating state with ${stops.length} stops.');
        
        state = state.copyWith(
          routeData: routeData,
          stops: stops,
          busPosition: stops.isNotEmpty ? stops.first.position : state.busPosition,
        );
        print('APP_STATE: State update complete. Bus position: ${state.busPosition}');
      } else {
        print('APP_STATE: Route data is still null after initialization attempt.');
      }
    } catch (e) {
      print("APP_STATE: Error initializing route: $e");
      debugPrint("Error initializing route: $e");
    }
  }

  Timer? _timer;
  int _tick = 0;

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
      lastUpdated: DateTime.now(),
      routeData: null,
    );
  }

  void _startSimulation() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (state.stops.isEmpty || state.routeCompleted) return;
      _tick++;

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

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

