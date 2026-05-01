import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'user_service.dart';

class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final UserService _userService = UserService();
  bool _isInitialized = false;
  Future<void>? _initializing;
  String _lastForegroundMessageKey = '';
  DateTime _lastForegroundMessageAt = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> initialize({GlobalKey<ScaffoldMessengerState>? messengerKey}) async {
    if (_isInitialized) return;
    if (_initializing != null) return _initializing!;

    _initializing = _initializeInternal(messengerKey: messengerKey);
    await _initializing;
    _initializing = null;
  }

  Future<void> _initializeInternal({GlobalKey<ScaffoldMessengerState>? messengerKey}) async {
    if (Firebase.apps.isEmpty) {
      debugPrint('[FCM] Firebase is not initialized. Skipping push notification setup.');
      return;
    }

    final androidInit = const AndroidInitializationSettings('@mipmap/ic_launcher');
    final initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(initSettings);

    final androidChannel = AndroidNotificationChannel(
      'viscous_default_channel',
      'Viscous updates',
      description: 'Foreground notifications for bus updates',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    await _messaging.setAutoInitEnabled(true);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    debugPrint('[FCM] permission: ${settings.authorizationStatus}');

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    String? token;
    try {
      token = await _messaging.getToken();
      debugPrint('[FCM] token: $token');
    } catch (error) {
      // FIS_AUTH_ERROR / emulator transient auth errors should never crash app.
      debugPrint('[FCM] token retrieval failed: $error');
    }

    if (token != null && token.isNotEmpty) {
      try {
        await _userService.upsertFcmToken(token);
      } catch (error) {
        debugPrint('[FCM] token upload failed: $error');
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? 'Notification';
      final body = message.notification?.body ?? message.data.toString();
      final currentKey = '${message.messageId ?? ''}|$title|$body';
      final now = DateTime.now();
      final isDuplicate =
          currentKey == _lastForegroundMessageKey &&
          now.difference(_lastForegroundMessageAt).inSeconds < 15;
      if (isDuplicate) {
        debugPrint('[FCM][fg] duplicate notification suppressed');
        return;
      }
      _lastForegroundMessageKey = currentKey;
      _lastForegroundMessageAt = now;
      debugPrint('[FCM][fg] $title — $body');
      _showForegroundSystemNotification(title: title, body: body);
      messengerKey?.currentState?.showSnackBar(
        SnackBar(
          content: Text('$title\n$body', maxLines: 3),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] opened from notification: ${message.messageId}');
    });

    _isInitialized = true;
  }

  Future<void> _showForegroundSystemNotification({
    required String title,
    required String body,
  }) async {
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'viscous_default_channel',
        'Viscous updates',
        channelDescription: 'Foreground notifications for bus updates',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
