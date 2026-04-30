import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_state.dart';
import 'firebase_background.dart';
import 'screens/app_shell_screen.dart';
import 'screens/login_screen.dart';
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

class BusTrackerApp extends ConsumerWidget {
  const BusTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);
    
    final router = GoRouter(
      initialLocation: isAuthenticated ? '/app' : '/login',
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/app',
          builder: (context, state) => const AppShellScreen(),
        ),
      ],
      redirect: (context, state) {
        final onLogin = state.matchedLocation == '/login';
        if (!isAuthenticated && !onLogin) {
          return '/login';
        }
        if (isAuthenticated && onLogin) {
          return '/app';
        }
        return null;
      },
    );

    return MaterialApp.router(
      title: 'Viscous Bus Tracker',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeMode,
      // ── LIGHT THEME ────────────────────────────────────────────────────────
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        dividerColor: const Color(0xFFE2E8F0),
        colorScheme: const ColorScheme.light(
          primary:   Color(0xFF0F4C81),
          secondary: Color(0xFF0284C7),
          surface:   Color(0xFFFFFFFF),
          surfaceContainerHighest: Color(0xFFEFF6FF),
          error:     Color(0xFFDC2626),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF002366)),
          bodyLarge:  TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
          bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black12,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
      ),
      // ── DARK THEME ─────────────────────────────────────────────────────────
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080D22),
        colorScheme: const ColorScheme.dark(
          primary:   Color(0xFF00D4FF),
          secondary: Color(0xFFFFB930),
          surface:   Color(0xFF0E1530),
          error:     Color(0xFFFF4D6D),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFEAF0FF)),
          bodyLarge:  TextStyle(fontSize: 15, color: Color(0xFFEAF0FF)),
          bodyMedium: TextStyle(fontSize: 13, color: Color(0xFF5A6A90)),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF0E1530),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
            side: BorderSide(color: Color(0xFF1A2550)),
          ),
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Color(0xFF0E1530),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            side: BorderSide(color: Color(0xFF1A2550)),
          ),
        ),
      ),
    );
  }
}
