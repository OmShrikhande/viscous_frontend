import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
<<<<<<< HEAD
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_state.dart';
import 'screens/app_shell_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const ProviderScope(child: BusTrackerApp()));
=======

import 'firebase_background.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/push_notification_service.dart';
import 'services/storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
>>>>>>> c1c5301a202ae6e6c351a186241b8a4d4ef7b395
}

class BusTrackerApp extends ConsumerWidget {
  const BusTrackerApp({super.key});

  @override
<<<<<<< HEAD
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
=======
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final StorageService _storageService = StorageService();
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.instance.initialize(messengerKey: _messengerKey);
    });
  }

  Future<void> _initializeApp() async {
    try {
      final isLoggedIn = await _storageService.isLoggedIn();
      final isDark = await _storageService.getDarkMode();
      if (mounted) {
        setState(() {
          _isLoggedIn = isLoggedIn;
          _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
    _storageService.setDarkMode(isDark);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        scaffoldMessengerKey: _messengerKey,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    const primaryColor = Color(0xFF002366);
    const accentColor = Color(0xFFE1AD01);

    return MaterialApp(
      scaffoldMessengerKey: _messengerKey,
      title: 'Viscous App',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
          primary: primaryColor,
          secondary: accentColor,
        ),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.dark,
          primary: primaryColor,
          secondary: accentColor,
        ),
      ),
      
      home: _isLoggedIn 
          ? HomeScreen(onThemeChanged: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark) 
          : LoginScreen(onThemeChanged: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark),
>>>>>>> c1c5301a202ae6e6c351a186241b8a4d4ef7b395
    );
  }
}
