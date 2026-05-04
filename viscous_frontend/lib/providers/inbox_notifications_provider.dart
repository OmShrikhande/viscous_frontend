import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/inbox_notification.dart';
import '../services/notifications_firestore_api.dart';

final notificationsFirestoreApiProvider = Provider<NotificationsFirestoreApi>((ref) {
  return NotificationsFirestoreApi();
});

/// Firestore-backed rows only (real-time).
final serverNotificationsStreamProvider = StreamProvider<List<InboxNotification>>((ref) {
  final api = ref.watch(notificationsFirestoreApiProvider);
  return api.watchServerNotifications();
});

class WelcomeDismissedNotifier extends StateNotifier<bool> {
  WelcomeDismissedNotifier() : super(false) {
    _load();
  }

  static const _key = 'welcome_notification_dismissed_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> setDismissed() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }
}

final welcomeDismissedProvider =
    StateNotifierProvider<WelcomeDismissedNotifier, bool>((ref) => WelcomeDismissedNotifier());
