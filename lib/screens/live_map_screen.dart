import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../widgets/bus_speed_gauge.dart';

/// Live map using Leaflet (embedded via WebView) plus bus speed overlay.
class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  late final WebViewController _webViewController;
  Timer? _speedTimer;
  double _speedKmh = 0;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0E21))
      ..loadFlutterAsset('assets/web/leaflet_map.html');

    final rnd = math.Random();
    _speedTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;
      final target = 32 + rnd.nextDouble() * 22;
      setState(() {
        _speedKmh = _speedKmh * 0.65 + target * 0.35;
      });
    });
  }

  @override
  void dispose() {
    _speedTimer?.cancel();
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
      ],
    );
  }
}
