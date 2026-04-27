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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const ProviderScope(child: BusTrackerApp()));
}
}

class BusTrackerApp extends ConsumerWidget {
  const BusTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.watch(authStateProvider);
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
      title: 'Parent Bus Tracker',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1E3A8A),
          secondary: Color(0xFFF59E0B),
          surface: Colors.white,
          error: Color(0xFFDC2626),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
