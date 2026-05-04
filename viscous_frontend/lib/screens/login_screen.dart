import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_state.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _storageService = StorageService();

  late AnimationController _waveCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _waveCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 14))
          ..repeat();
    _fadeCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _waveCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final response = await authService.login(_phoneController.text.trim());
      await _storageService.saveLoginData(response);
      ref.read(authStateProvider.notifier).state = true;
      if (mounted) context.go('/app');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed. Please check your credentials.'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ── Per-mode palette ────────────────────────────────────────────────────
    final bg = isDark ? const Color(0xFF050A1E) : const Color(0xFFEEF2FF);
    final surface = isDark ? const Color(0xFF0C1230) : Colors.white;
    final border = isDark ? const Color(0xFF1C2B5A) : const Color(0xFFBFDBFE);
    final primary = isDark ? const Color(0xFF00D4FF) : const Color(0xFF1D4ED8);
    final primaryDim = isDark ? const Color(0xFF0099CC) : const Color(0xFF2563EB);
    final text = isDark ? const Color(0xFFEAF0FF) : const Color(0xFF1E293B);
    final textDim = isDark ? const Color(0xFF4A5D8A) : const Color(0xFF64748B);
    final amber = isDark ? const Color(0xFFFFB930) : const Color(0xFFD97706);

    final waveColors = isDark
        ? [const Color(0xFF00D4FF), const Color(0xFFFFB930), const Color(0xFF00D4FF)]
        : [const Color(0xFF1D4ED8), const Color(0xFF2563EB), const Color(0xFF1D4ED8)];

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // ── Wave background ───────────────────────────────────────────────
          AnimatedBuilder(
            animation: _waveCtrl,
            builder: (context, child) => CustomPaint(
              painter: _WavePainter(_waveCtrl.value, waveColors, isDark),
              size: size,
            ),
          ),

          // ── Glow orbs ─────────────────────────────────────────────────────
          Positioned(
            top: size.height * 0.06,
            left: size.width * 0.55,
            child: _GlowOrb(color: primary, size: 200, opacity: isDark ? 0.12 : 0.08),
          ),
          Positioned(
            top: size.height * 0.52,
            left: -40,
            child: _GlowOrb(color: amber, size: 150, opacity: isDark ? 0.10 : 0.07),
          ),
          Positioned(
            top: size.height * 0.33,
            right: -25,
            child: _GlowOrb(color: primary, size: 110, opacity: isDark ? 0.08 : 0.06),
          ),

          // ── Main content ──────────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildBranding(isDark, primary, text, textDim, surface, amber),
                        const SizedBox(height: 44),
                        _buildLoginCard(
                          isDark: isDark,
                          surface: surface,
                          border: border,
                          primary: primary,
                          primaryDim: primaryDim,
                          text: text,
                          textDim: textDim,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Branding ───────────────────────────────────────────────────────────────
  Widget _buildBranding(bool isDark, Color primary, Color text, Color textDim,
      Color surface, Color amber) {
    return Column(
      children: [
        // Shield + bus icon stack
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 106,
              height: 106,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [primary.withValues(alpha: 0.2), Colors.transparent],
                ),
              ),
            ),
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: surface,
                border: Border.all(color: primary.withValues(alpha: 0.55), width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: isDark ? 0.35 : 0.2),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.shield_rounded, color: primary.withValues(alpha: 0.15), size: 52),
                  Icon(Icons.directions_bus_rounded, color: primary, size: 38),
                ],
              ),
            ),
            // Safety badge
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: amber,
                  shape: BoxShape.circle,
                  border: Border.all(color: surface, width: 2),
                ),
                child: const Icon(Icons.verified_rounded, color: Colors.white, size: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          'VISCOUS',
          style: TextStyle(
            fontSize: 38,
            fontWeight: FontWeight.w900,
            color: text,
            letterSpacing: 9,
            shadows: [Shadow(color: primary.withValues(alpha: 0.5), blurRadius: 20)],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'SAFE PARENT BUS TRACKER',
          style: TextStyle(
            color: textDim,
            fontSize: 10.5,
            letterSpacing: 3.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ─── Login card ─────────────────────────────────────────────────────────────
  Widget _buildLoginCard({
    required bool isDark,
    required Color surface,
    required Color border,
    required Color primary,
    required Color primaryDim,
    required Color text,
    required Color textDim,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: surface.withValues(alpha: isDark ? 0.72 : 0.9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: isDark ? 0.08 : 0.06),
                blurRadius: 40,
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.lock_rounded, color: primary, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sign In',
                            style: TextStyle(
                                color: text, fontSize: 20, fontWeight: FontWeight.w800)),
                        Text('Welcome back — please verify yourself.',
                            style: TextStyle(color: textDim, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Phone field
                _buildField(
                  label: 'PHONE NUMBER',
                  hint: 'Enter your registered phone number',
                  icon: Icons.phone_android_rounded,
                  controller: _phoneController,
                  inputType: TextInputType.phone,
                  primary: primary,
                  text: text,
                  textDim: textDim,
                  border: border,
                  isDark: isDark,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Phone number is required';
                    if (!RegExp(r'^\+?[0-9]{7,15}$').hasMatch(v.trim())) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: _isLoading
                            ? [primary.withValues(alpha: 0.4), primary.withValues(alpha: 0.25)]
                            : [primary, primaryDim],
                      ),
                      boxShadow: _isLoading
                          ? []
                          : [
                              BoxShadow(
                                color: primary.withValues(alpha: isDark ? 0.45 : 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: isDark ? Colors.black87 : Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.login_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                const Text(
                                  'SECURE LOGIN',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.security_rounded, size: 12, color: textDim.withValues(alpha: 0.5)),
                      const SizedBox(width: 5),
                      Text(
                        'Protected by Viscous Security™',
                        style: TextStyle(color: textDim.withValues(alpha: 0.5), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    required Color primary,
    required Color text,
    required Color textDim,
    required Color border,
    required bool isDark,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final fillColor = isDark ? const Color(0xFF050A1E).withValues(alpha: 0.6) : const Color(0xFFEFF6FF);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: textDim,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.9,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: inputType,
          validator: validator,
          style: TextStyle(color: text, fontSize: 14),
          cursorColor: primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: textDim.withValues(alpha: 0.5), fontSize: 13),
            prefixIcon: Icon(icon, color: primary, size: 19),
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFFF4D6D)),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFFF4D6D)),
            ),
            errorStyle: const TextStyle(color: Color(0xFFFF4D6D)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
        ),
      ],
    );
  }
}

// ─── Wave background painter ──────────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  final double t;
  final List<Color> colors;
  final bool isDark;
  _WavePainter(this.t, this.colors, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    _draw(canvas, size, 0.65, 42, t, colors[0], isDark ? 0.06 : 0.05);
    _draw(canvas, size, 0.72, 30, -t, colors[1], isDark ? 0.04 : 0.04);
    _draw(canvas, size, 0.80, 20, t * 1.3, colors[2], isDark ? 0.03 : 0.03);
  }

  void _draw(Canvas canvas, Size size, double yFactor, double amp, double phase,
      Color color, double opacity) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    final path = Path();
    final yBase = size.height * yFactor;
    path.moveTo(0, size.height);
    path.lineTo(0, yBase);
    for (double x = 0; x <= size.width; x++) {
      final y = yBase +
          amp * math.sin((x / size.width * 2 * math.pi) + phase * 2 * math.pi);
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.t != t || old.isDark != isDark;
}

// ─── Glow orb ─────────────────────────────────────────────────────────────────
class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _GlowOrb({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: opacity), Colors.transparent],
        ),
      ),
    );
  }
}