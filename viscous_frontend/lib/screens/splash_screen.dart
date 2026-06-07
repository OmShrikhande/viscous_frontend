import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';


import '../app_state.dart';


/// Premium animated splash screen.
/// Shows for ~2.8 seconds then auto-redirects to /login or /app.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // ── Master timeline ────────────────────────────────────────────────────────
  late final AnimationController _masterCtrl;

  // ── Logo animations ────────────────────────────────────────────────────────
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoPulse;

  // ── Text animations ────────────────────────────────────────────────────────
  late final Animation<double> _titleOpacity;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleOpacity;
  late final Animation<Offset> _subtitleSlide;

  // ── Particle / orbit animation ─────────────────────────────────────────────
  late final AnimationController _orbitCtrl;

  // ── Bottom brand animation ─────────────────────────────────────────────────
  late final Animation<double> _brandOpacity;

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      FlutterNativeSplash.remove();
    }

    // Master: 2000ms drives all entry animations
    _masterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Orbit spins forever
    _orbitCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _buildAnimations();
    _startSequence();
  }

  void _buildAnimations() {
    // Logo scales from 0.3 → 1.0 in first 600ms then slight overshoot bounce
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.3, end: 1.08).chain(CurveTween(curve: Curves.easeOut)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 0.96).chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.96, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 30,
      ),
    ]).animate(_masterCtrl);

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut),
      ),
    );

    // Pulse breathe after logo lands — 1.0 → 1.06 → 1.0
    _logoPulse = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.65, 1.0, curve: Curves.easeInOut),
    ));

    // Title slides up from +20px
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
      ),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.35, 0.65, curve: Curves.easeOut),
    ));

    // Subtitle fades in after title
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.55, 0.80, curve: Curves.easeOut),
      ),
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.55, 0.80, curve: Curves.easeOut),
    ));

    // EISTATECH brand line at bottom
    _brandOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterCtrl,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  Future<void> _startSequence() async {
    await _masterCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 800));
    // Navigate while splash is still opaque — fading to transparent first
    // exposed the navigator's default white surface for a frame.
    if (mounted && !_navigated) {
      _navigated = true;
      final isLoggedIn = ref.read(authStateProvider);
      context.go(isLoggedIn ? '/app' : '/login');
    }
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _orbitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: const Color(0xFF060C1E),
      body: AnimatedBuilder(
          animation: Listenable.merge([_masterCtrl, _orbitCtrl]),
          builder: (context, _) {
            return Stack(
              children: [
                // ── Radial gradient background ───────────────────────────────
                Positioned.fill(
                  child: CustomPaint(
                    painter: _BackgroundPainter(
                      progress: _masterCtrl.value,
                      orbit: _orbitCtrl.value,
                    ),
                  ),
                ),

                // ── Centre content ───────────────────────────────────────────
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo badge
                      Transform.scale(
                        scale: _logoPulse.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Opacity(
                            opacity: _logoOpacity.value,
                            child: _LogoBadge(orbitValue: _orbitCtrl.value),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // App name
                      SlideTransition(
                        position: _titleSlide,
                        child: FadeTransition(
                          opacity: _titleOpacity,
                          child: const Text(
                            'VISCOUS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 8,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Tagline
                      SlideTransition(
                        position: _subtitleSlide,
                        child: FadeTransition(
                          opacity: _subtitleOpacity,
                          child: const Text(
                            'Real-time School Bus Tracker',
                            style: TextStyle(
                              color: Color(0xFF7A9EFF),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Bottom EISTATECH brand ───────────────────────────────────
                Positioned(
                  bottom: 40,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _brandOpacity,
                    child: Column(
                      children: [
                        const Text(
                          'POWERED BY',
                          style: TextStyle(
                            color: Color(0xFF3A4A70),
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        const Text(
                          'EISTATECH',
                          style: TextStyle(
                            color: Color(0xFF4D7CFF),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
    );
  }
}

// ─── Logo badge with orbit ring ───────────────────────────────────────────────
class _LogoBadge extends StatelessWidget {
  final double orbitValue;
  const _LogoBadge({required this.orbitValue});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                  blurRadius: 50,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: const Color(0xFF00D4FF).withValues(alpha: 0.18),
                  blurRadius: 80,
                  spreadRadius: 20,
                ),
              ],
            ),
          ),
          // Rotating orbit ring
          Transform.rotate(
            angle: orbitValue * 2 * math.pi,
            child: CustomPaint(
              size: const Size(118, 118),
              painter: _OrbitRingPainter(),
            ),
          ),
          // Inner badge circle
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1A3A8F), Color(0xFF0E1F5C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: const Color(0xFF2563EB).withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: _BusLogoIcon(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Orbit ring painter ───────────────────────────────────────────────────────
class _OrbitRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Dashed orbit ring
    final paint = Paint()
      ..color = const Color(0xFF2563EB).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashCount = 18;
    const dashAngle = math.pi / dashCount;

    for (int i = 0; i < dashCount * 2; i += 2) {
      final startAngle = i * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle * 0.6,
        false,
        paint,
      );
    }

    // Orbit dot (bright node)
    canvas.drawCircle(
      Offset(center.dx + radius, center.dy),
      4,
      Paint()
        ..color = const Color(0xFF00D4FF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(
      Offset(center.dx + radius, center.dy),
      3,
      Paint()..color = const Color(0xFF00D4FF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── Minimalist bus front-view icon ──────────────────────────────────────────
class _BusLogoIcon extends StatelessWidget {
  const _BusLogoIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(52, 52),
      painter: _BusIconPainter(),
    );
  }
}

class _BusIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bus body
    final bodyRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.05, h * 0.08, w * 0.90, h * 0.66),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..shader = LinearGradient(
          colors: [const Color(0xFF2563EB), const Color(0xFF1D4ED8)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Safety stripe
    canvas.drawRect(
      Rect.fromLTWH(w * 0.05, h * 0.46, w * 0.90, h * 0.07),
      Paint()..color = const Color(0xFFFFCC00),
    );

    // Windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.14, h * 0.14, w * 0.72, h * 0.26),
        const Radius.circular(5),
      ),
      Paint()
        ..color = const Color(0xFF93C5FD).withValues(alpha: 0.8),
    );

    // Front light (left)
    canvas.drawCircle(
      Offset(w * 0.22, h * 0.74),
      w * 0.07,
      Paint()
        ..color = const Color(0xFFFEF08A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      Offset(w * 0.22, h * 0.74),
      w * 0.045,
      Paint()..color = const Color(0xFFFEF08A),
    );

    // Front light (right)
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.74),
      w * 0.07,
      Paint()
        ..color = const Color(0xFFFEF08A)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.74),
      w * 0.045,
      Paint()..color = const Color(0xFFFEF08A),
    );

    // Wheels
    canvas.drawCircle(
      Offset(w * 0.27, h * 0.90),
      w * 0.10,
      Paint()..color = const Color(0xFF1E293B),
    );
    canvas.drawCircle(
      Offset(w * 0.27, h * 0.90),
      w * 0.06,
      Paint()
        ..color = const Color(0xFF64748B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(w * 0.73, h * 0.90),
      w * 0.10,
      Paint()..color = const Color(0xFF1E293B),
    );
    canvas.drawCircle(
      Offset(w * 0.73, h * 0.90),
      w * 0.06,
      Paint()
        ..color = const Color(0xFF64748B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Emergency roof lights
    canvas.drawCircle(
      Offset(w * 0.38, h * 0.06),
      4,
      Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(Offset(w * 0.38, h * 0.06), 2.5, Paint()..color = const Color(0xFFEF4444));
    canvas.drawCircle(
      Offset(w * 0.62, h * 0.06),
      4,
      Paint()
        ..color = const Color(0xFF60A5FA).withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(Offset(w * 0.62, h * 0.06), 2.5, Paint()..color = const Color(0xFF60A5FA));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Background gradient + floating particles ─────────────────────────────────
class _BackgroundPainter extends CustomPainter {
  final double progress;
  final double orbit;
  _BackgroundPainter({required this.progress, required this.orbit});

  @override
  void paint(Canvas canvas, Size size) {
    // Deep navy gradient
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.3),
          radius: 0.9,
          colors: [
            Color.lerp(const Color(0xFF0A1535), const Color(0xFF112060), progress)!,
            const Color(0xFF060C1E),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Floating dot particles
    final rng = math.Random(42);
    for (int i = 0; i < 28; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final phase = rng.nextDouble() * math.pi * 2;
      final speed = 0.3 + rng.nextDouble() * 0.7;
      final radius = 0.8 + rng.nextDouble() * 2.0;
      final alpha = (0.04 + rng.nextDouble() * 0.12) * progress;

      final x = baseX + math.sin(orbit * 2 * math.pi * speed + phase) * 8;
      final y = baseY + math.cos(orbit * 2 * math.pi * speed + phase) * 5;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = const Color(0xFF4D7CFF).withValues(alpha: alpha),
      );
    }

    // Blue glow bloom around centre
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.38),
      160 * progress,
      Paint()
        ..color = const Color(0xFF1D4ED8).withValues(alpha: 0.08 * progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60),
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.38),
      80 * progress,
      Paint()
        ..color = const Color(0xFF00D4FF).withValues(alpha: 0.05 * progress)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
    );
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter old) =>
      old.progress != progress || old.orbit != orbit;
}
