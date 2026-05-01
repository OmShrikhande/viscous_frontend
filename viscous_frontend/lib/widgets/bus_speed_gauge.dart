import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Circular speed readout (km/h) for the live map overlay.
class BusSpeedGauge extends StatelessWidget {
  final double speedKmh;
  final double maxKmh;

  const BusSpeedGauge({
    super.key,
    required this.speedKmh,
    this.maxKmh = 80,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = speedKmh.clamp(0.0, maxKmh);
    final fraction = maxKmh > 0 ? clamped / maxKmh : 0.0;

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withValues(alpha: 0.45),
        border: Border.all(color: const Color(0xFFE1AD01), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _SpeedRingPainter(fraction: fraction),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                clamped.round().toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const Text(
                'km/h',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpeedRingPainter extends CustomPainter {
  final double fraction;

  _SpeedRingPainter({required this.fraction});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    const royal = Color(0xFF002366);
    const gold = Color(0xFFE1AD01);

    final bg = Paint()
      ..color = royal.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final fg = Paint()
      ..color = gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    const start = -math.pi * 0.75;
    const sweep = math.pi * 1.5;

    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, sweep, false, bg);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, sweep * fraction, false, fg);
  }

  @override
  bool shouldRepaint(covariant _SpeedRingPainter oldDelegate) =>
      oldDelegate.fraction != fraction;
}
