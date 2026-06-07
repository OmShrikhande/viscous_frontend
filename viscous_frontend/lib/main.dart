import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_state.dart';
import 'firebase_background.dart';
import 'screens/app_shell_screen.dart';
import 'screens/login_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/splash_screen.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Firebase is not configured for web yet — skip gracefully so the
  // Flutter UI still runs. Wire up firebase_options.dart when ready.
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    // ignore: avoid_print
    print('[main] Firebase init skipped on this platform: $e');
  }

  final storageService = StorageService();
  final isLoggedIn = await storageService.isLoggedIn();

  runApp(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => isLoggedIn),
      ],
      child: const BusTrackerApp(),
    ),
  );
}

/// Stable router instance — must not be recreated on auth changes or the app
/// resets to [initialLocation] and shows the splash again after login/logout.
final goRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    // Splash only on cold start; login/logout navigate directly elsewhere.
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) => const AppShellScreen(),
      ),
      GoRoute(
        path: '/app/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
    redirect: (context, state) {
      final location = state.matchedLocation;
      // Let the splash screen pass through — it navigates itself.
      if (location == '/') return null;
      final isAuthenticated = ref.read(authStateProvider);
      final onLogin = location == '/login';
      if (!isAuthenticated && !onLogin) return '/login';
      if (isAuthenticated && onLogin) return '/app';
      return null;
    },
  );

  ref.listen<bool>(authStateProvider, (_, __) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});

class BusTrackerApp extends ConsumerWidget {
  const BusTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Viscous',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeMode,
      // Dark navy behind every route — visible during fade transitions so there
      // is never a white frame between splash → login / app.
      color: const Color(0xFF060C1E),
      builder: (context, child) => ColoredBox(
        color: const Color(0xFF060C1E),
        child: child ?? const SizedBox.shrink(),
      ),

      // ── LIGHT THEME ── Safety-first: royal blue authority + amber school bus ──
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: GoogleFonts.inter().fontFamily,
        scaffoldBackgroundColor: const Color(0xFFEEF2FF),
        // Fade transition on every route change — no jarring white flash.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _FadeTransitionBuilder(),
            TargetPlatform.iOS:     _FadeTransitionBuilder(),
            TargetPlatform.linux:   _FadeTransitionBuilder(),
            TargetPlatform.macOS:   _FadeTransitionBuilder(),
            TargetPlatform.windows: _FadeTransitionBuilder(),
          },
        ),
        dividerColor: const Color(0xFFBFDBFE),
        colorScheme: const ColorScheme.light(
          primary:   Color(0xFF1D4ED8),   // royal blue – authority & safety
          secondary: Color(0xFFD97706),   // amber – school bus
          surface:   Color(0xFFFFFFFF),
          surfaceContainerHighest: Color(0xFFDBEAFE),
          error:     Color(0xFFDC2626),
          onPrimary: Color(0xFFFFFFFF),
          onSecondary: Color(0xFFFFFFFF),
          onSurface: Color(0xFF0F172A),
        ),
        textTheme: const TextTheme(
          displaySmall: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E3A5F), letterSpacing: -0.5),
          titleLarge:   TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1E3A5F)),
          titleMedium:  TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1E3A5F)),
          bodyLarge:    TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
          bodyMedium:   TextStyle(fontSize: 13, color: Color(0xFF475569)),
          labelSmall:   TextStyle(fontSize: 10, color: Color(0xFF64748B), letterSpacing: 0.8),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          shadowColor: Color(0x1A1D4ED8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFBFDBFE)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFEFF6FF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFBFDBFE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFBFDBFE)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 2),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1D4ED8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            side: BorderSide(color: Color(0xFFBFDBFE)),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8)),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
        ),
      ),

      // ── DARK THEME ── Power mode: electric cyan + deep navy ──────────────
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: GoogleFonts.inter().fontFamily,
        scaffoldBackgroundColor: const Color(0xFF080D22),
        // Fade transition on every route change — no jarring white flash.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _FadeTransitionBuilder(),
            TargetPlatform.iOS:     _FadeTransitionBuilder(),
            TargetPlatform.linux:   _FadeTransitionBuilder(),
            TargetPlatform.macOS:   _FadeTransitionBuilder(),
            TargetPlatform.windows: _FadeTransitionBuilder(),
          },
        ),
        dividerColor: const Color(0xFF1A2550),
        colorScheme: const ColorScheme.dark(
          primary:   Color(0xFF00D4FF),   // electric cyan
          secondary: Color(0xFFFFB930),   // amber gold
          surface:   Color(0xFF0E1530),
          surfaceContainerHighest: Color(0xFF131E3A),
          error:     Color(0xFFFF4D6D),
          onPrimary: Color(0xFF000D1A),
          onSecondary: Color(0xFF1A0A00),
          onSurface: Color(0xFFEAF0FF),
        ),
        textTheme: const TextTheme(
          displaySmall: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFEAF0FF), letterSpacing: -0.5),
          titleLarge:   TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFEAF0FF)),
          titleMedium:  TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEAF0FF)),
          bodyLarge:    TextStyle(fontSize: 15, color: Color(0xFFEAF0FF)),
          bodyMedium:   TextStyle(fontSize: 13, color: Color(0xFF7A8EBF)),
          labelSmall:   TextStyle(fontSize: 10, color: Color(0xFF5A6A90), letterSpacing: 0.8),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF0E1530),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFF1A2550)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0A1028),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1A2550)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF1A2550)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 1.5),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D4FF),
            foregroundColor: const Color(0xFF000D1A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF0E1530),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            side: BorderSide(color: Color(0xFF1A2550)),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? const Color(0xFF00D4FF) : const Color(0xFF334155)),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? const Color(0xFF0E3A4A) : const Color(0xFF1A2550)),
        ),
      ),
    );
  }
}

// ─── Smooth fade transition for every GoRouter page change ───────────────────
// Replaces the default platform slide/cut transition so there is no white
// frame between the dark splash and the login / app screens.
class _FadeTransitionBuilder implements PageTransitionsBuilder {
  const _FadeTransitionBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 250);

  @override
  DelegatedTransitionBuilder? get delegatedTransition => null;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      // 350ms ease-in-out — feels instant but avoids a hard cut
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOut,
      ),
      child: child,
    );
  }
}
