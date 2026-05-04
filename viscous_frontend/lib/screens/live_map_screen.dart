import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/location_service.dart';
import '../widgets/bus_speed_gauge.dart';

/// Live map using Leaflet (embedded via WebView) plus bus speed overlay.
class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  late final WebViewController _webViewController;
  Timer? _locationTimer;
  final LocationService _locationService = LocationService();
  double _speedKmh = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0E21))
      ..loadFlutterAsset('assets/web/leaflet_map.html');

    // Start polling for bus location every 8 seconds
    _locationTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      _fetchBusLocation();
    });

    // Initial fetch
    _fetchBusLocation();
  }

  Future<void> _fetchBusLocation() async {
    if (!mounted) return;

    try {
      final locationData = await _locationService.getBusLocation();

      setState(() {
        _speedKmh = (locationData['speedKmh'] as num?)?.toDouble() ?? 0;
        _isLoading = false;
        _errorMessage = null;
      });

      // Update bus position on map
      final lat = locationData['latitude'];
      final lng = locationData['longitude'];
      if (lat != null && lng != null) {
        _webViewController.runJavaScript('updateBusPosition($lat, $lng);');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        WebViewWidget(controller: _webViewController),
        Positioned(
          right: 16,
          bottom: 24,
          child: BusSpeedGauge(speedKmh: _speedKmh),
        ),
        // Loading overlay
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF00D4FF),
              ),
            ),
          ),
        // Error overlay
        if (_errorMessage != null)
          Container(
            color: Colors.black54,
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load bus location',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _fetchBusLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
