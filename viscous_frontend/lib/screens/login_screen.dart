import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_state.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';

// ─── Design tokens ────────────────────────────────────────────────────────────
const Color _kBg      = Color(0xFF050A1E);
const Color _kSurface = Color(0xFF0C1230);
const Color _kBorder  = Color(0xFF1C2B5A);
const Color _kCyan    = Color(0xFF00D4FF);
const Color _kAmber   = Color(0xFFFFB930);
const Color _kText    = Color(0xFFEAF0FF);
const Color _kTextDim = Color(0xFF4A5D8A);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _formKey             = GlobalKey<FormState>();
  final _phoneController     = TextEditingController();
  final _storageService      = StorageService();

  late AnimationController _waveCtrl;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  bool _isLoading       = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
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
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authService = AuthService();
      final response = await authService.login(_phoneController.text);

      await _storageService.saveLoginData(response);
      ref.read(authStateProvider.notifier).state = true;
      if (mounted) context.go('/app');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // ── Animated wave background ──────────────────────────────────
          AnimatedBuilder(
            animation: _waveCtrl,
            builder: (_, __) => CustomPaint(
              painter: _WavePainter(_waveCtrl.value),
              size: size,
            ),
          ),

          // ── Scattered glow orbs ───────────────────────────────────────
          Positioned(top: size.height * 0.08, left: size.width * 0.6,
            child: _GlowOrb(color: _kCyan, size: 180)),
          Positioned(top: size.height * 0.55, left: -30,
            child: _GlowOrb(color: _kAmber, size: 140)),
          Positioned(top: size.height * 0.35, right: -20,
            child: _GlowOrb(color: _kCyan, size: 100)),

          // ── Main content ──────────────────────────────────────────────
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
                        _buildBranding(),
                        const SizedBox(height: 44),
                        _buildGlassCard(),
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

  // ──────────────────────────────────────────────────────────────────────────
  // Branding
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildBranding() {
    return Column(children: [
      // Icon ring
      Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [_kCyan.withOpacity(0.18), Colors.transparent],
              ),
            ),
          ),
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kSurface,
              border: Border.all(color: _kCyan.withOpacity(0.6), width: 2),
              boxShadow: [BoxShadow(color: _kCyan.withOpacity(0.35), blurRadius: 28)],
            ),
            child: const Icon(Icons.directions_bus_rounded, size: 38, color: _kCyan),
          ),
        ],
      ),
      const SizedBox(height: 20),
      const Text(
        'VISCOUS',
        style: TextStyle(
          fontSize: 36, fontWeight: FontWeight.w900, color: _kText,
          letterSpacing: 8,
          shadows: [Shadow(color: Color(0xFF00D4FF), blurRadius: 16)],
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'PARENT BUS TRACKER',
        style: TextStyle(color: _kTextDim, fontSize: 11, letterSpacing: 3.5,
            fontWeight: FontWeight.w600),
      ),
    ]);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Glass login card
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildGlassCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: _kSurface.withOpacity(0.7),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _kCyan.withOpacity(0.18), width: 1.5),
            boxShadow: [BoxShadow(color: _kCyan.withOpacity(0.06), blurRadius: 40)],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Sign In',
                    style: TextStyle(color: _kText, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Welcome back! Please enter your credentials.',
                    style: TextStyle(color: _kTextDim, fontSize: 12)),
                const SizedBox(height: 28),

                // Phone field
                _buildField(
                  controller:  _phoneController,
                  label:       'Phone Number',
                  hint:        'Enter your phone number',
                  icon:        Icons.phone_android_rounded,
                  inputType:   TextInputType.phone,
                  validator:   (v) => (v == null || v.isEmpty) ? 'Phone number is required' : null,
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
                            ? [_kCyan.withOpacity(0.4), _kCyan.withOpacity(0.2)]
                            : [_kCyan, const Color(0xFF0099CC)],
                      ),
                      boxShadow: _isLoading
                          ? []
                          : [BoxShadow(color: _kCyan.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 6))],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('LOGIN',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                                  letterSpacing: 2, color: Colors.white)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Center(
                  child: Text('Protected by Viscous Security™',
                      style: TextStyle(color: _kTextDim.withOpacity(0.5), fontSize: 10)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Input field
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    TextInputType inputType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: _kTextDim, fontSize: 11,
                fontWeight: FontWeight.w700, letterSpacing: 0.8)),
        const SizedBox(height: 8),
        TextFormField(
          controller:    controller,
          obscureText:   isPassword && _obscurePassword,
          keyboardType:  inputType,
          validator:     validator,
          style: const TextStyle(color: _kText, fontSize: 14),
          cursorColor:   _kCyan,
          decoration: InputDecoration(
            hintText:       hint,
            hintStyle:      TextStyle(color: _kTextDim.withOpacity(0.5), fontSize: 13),
            prefixIcon:     Icon(icon, color: _kCyan, size: 19),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                        _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: _kTextDim, size: 19),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  )
                : null,
            filled:       true,
            fillColor:    _kBg.withOpacity(0.6),
            border:       OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _kBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _kBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: _kCyan, width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFFF4D6D))),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFFF4D6D))),
            errorStyle:     const TextStyle(color: Color(0xFFFF4D6D)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Wave background painter
// ─────────────────────────────────────────────────────────────────────────────

class _WavePainter extends CustomPainter {
  final double t;
  _WavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    _draw(canvas, size, 0.65, 40, t,   const Color(0xFF00D4FF), 0.06);
    _draw(canvas, size, 0.72, 28, -t,  const Color(0xFFFFB930), 0.04);
    _draw(canvas, size, 0.80, 18, t*1.3, const Color(0xFF00D4FF), 0.03);
  }

  void _draw(Canvas canvas, Size size, double yFactor, double amp, double phase,
      Color color, double opacity) {
    final paint = Paint()
      ..color = color.withOpacity(opacity)
      ..style = PaintingStyle.fill;
    final path = Path();
    final yBase = size.height * yFactor;
    path.moveTo(0, size.height);
    path.lineTo(0, yBase);
    for (double x = 0; x <= size.width; x++) {
      final y = yBase + amp * math.sin((x / size.width * 2 * math.pi) + phase * 2 * math.pi);
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// Glow orb
// ─────────────────────────────────────────────────────────────────────────────

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _GlowOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withOpacity(0.12), Colors.transparent],
        ),
      ),
    );
  }
}