import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:math' as math;
import 'dart:ui';
import '../app_state.dart';
import '../services/storage_service.dart';
import '../models/login_response.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});


  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storageService = StorageService();

  late AnimationController _animationController;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Royal Blue & Mustard theme
  static const Color royalBlue = Color(0xFF002366);
  static const Color mustardGold = Color(0xFFE1AD01);
  static const Color white = Colors.white;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _mobileController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_mobileController.text.trim().length < 10) {
      _show('Enter a valid mobile number');
      return;
    }
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() {
      _otpSent = true;
      _loading = false;
    });
    _show('OTP sent to ${_mobileController.text.trim()}');
  }

  Future<void> _verifyOtp() async {
    if (_otpController.text.trim().length < 4) {
      _show('Enter a valid OTP');
      return;
    }
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    ref.read(authStateProvider.notifier).state = true;
    if (!mounted) return;
    setState(() => _loading = false);
    context.go('/app');
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  Future<void> _login() async {
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(seconds: 1));

    // Demo user data
    final mockResponse = LoginResponse(
      success: true,
      token: "mock_token_active",
      user: User(
        uid: "DV_9921",
        mobile: _mobileController.text.isEmpty ? "9112233445" : _mobileController.text,
        email: "demo_user@viscous.app",
        routeNumber: 42,
      ),
      message: "Direct Login Successful",
    );

    await _storageService.saveLoginData(mockResponse);
    ref.read(authStateProvider.notifier).state = true;

    if (mounted) {
      context.go('/app');
    }
>>>>>>> c1c5301a202ae6e6c351a186241b8a4d4ef7b395
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: royalBlue,
      body: Stack(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.directions_bus,
                        size: 56,
                        color: Color(0xFF1E3A8A),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Track Your Child\'s Bus',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Mobile Number',
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_otpSent)
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'OTP',
                            prefixIcon: Icon(Icons.password),
                          ),
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loading
                            ? null
                            : (_otpSent ? _verifyOtp : _sendOtp),
                        child: Text(
                          _loading
                              ? 'Please wait...'
                              : _otpSent
                              ? 'Verify OTP'
                              : 'Continue',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
=======
      backgroundColor: royalBlue,
      body: Stack(
        children: [
          _buildBackgroundWaves(size),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBranding(),
                    const SizedBox(height: 40),
                    _buildGlassCard(size),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundWaves(Size size) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: WavePainter(
            animationValue: _animationController.value,
            color1: mustardGold.withOpacity(0.12),
            color2: white.withOpacity(0.05),
          ),
          size: Size(size.width, size.height),
        );
      },
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: mustardGold, width: 3),
            color: white.withOpacity(0.1),
          ),
          child: const Icon(Icons.security_rounded, size: 56, color: mustardGold),
        ),
        const SizedBox(height: 20),
        const Text(
          'VISCOUS APP',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: white,
            letterSpacing: 4,
            shadows: [Shadow(color: Colors.black26, offset: Offset(2, 2), blurRadius: 4)],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard(Size size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(40),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: math.min(size.width * 0.9, 420),
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          decoration: BoxDecoration(
            color: white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: white.withOpacity(0.25), width: 1.5),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const Text(
                  'L O G I N',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: white,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 40),

                _buildRoundedTextField(
                  controller: _mobileController,
                  label: 'MOBILE NUMBER',
                  icon: Icons.phone_android_rounded,
                  hint: 'Enter Number',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Mobile number is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 25),

                _buildRoundedTextField(
                  controller: _passwordController,
                  label: 'PASSWORD',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  hint: '••••••••',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 50),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mustardGold,
                      foregroundColor: royalBlue,
                      elevation: 10,
                      shadowColor: Colors.black45,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: royalBlue)
                        : const Text(
                            'CONTINUE',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                  ),
                ),
              ],
>>>>>>> c1c5301a202ae6e6c351a186241b8a4d4ef7b395
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundedTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(color: mustardGold, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF001233).withOpacity(0.5),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: white.withOpacity(0.2)),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword && _obscurePassword,
            style: const TextStyle(color: white, fontSize: 16, fontWeight: FontWeight.w500),
            cursorColor: mustardGold,
            validator: validator,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: white.withOpacity(0.35), fontSize: 15),
              prefixIcon: Icon(icon, color: mustardGold, size: 22),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: white.withOpacity(0.6),
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              errorStyle: const TextStyle(color: Colors.redAccent, height: 0),
            ),
          ),
        ),
      ],
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;
  final Color color1;
  final Color color2;

  WavePainter({required this.animationValue, required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = color1..style = PaintingStyle.fill;
    final paint2 = Paint()..color = color2..style = PaintingStyle.fill;

    _drawWave(canvas, size, paint1, 0.72, 35, animationValue);
    _drawWave(canvas, size, paint2, 0.78, 20, -animationValue);
  }

  void _drawWave(Canvas canvas, Size size, Paint paint, double hFactor, double amplitude, double anim) {
    final path = Path();
    final yCenter = size.height * hFactor;
    path.moveTo(0, size.height);
    path.lineTo(0, yCenter);
    for (double i = 0; i <= size.width; i++) {
      final x = i;
      final y = yCenter + amplitude * math.sin((i / size.width * 2 * math.pi) + (anim * 2 * math.pi));
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) => true;
}
>>>>>>> c1c5301a202ae6e6c351a186241b8a4d4ef7b395
