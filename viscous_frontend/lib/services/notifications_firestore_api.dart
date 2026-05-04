import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../models/inbox_notification.dart';

/// Reads the `notification` collection in real time.
///
/// Layout:
/// - **Date document**: `notification/{dateId}` with fields such as `title`, `body`,
///   `message`, `heading`, `createdAt`, plus any extra fields (shown as a short summary).
/// - **Optional sub-items** (multiple notices per day): if a date document has no
///   `title`/`heading`/`subject` and no `body`/`message`/`description`, the app loads
///   `notification/{dateId}/items/*` the same way.
class NotificationsFirestoreApi {
  NotificationsFirestoreApi({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  bool get _firebaseReady => Firebase.apps.isNotEmpty;

  /// Live stream of server notifications (no welcome row).
  Stream<List<InboxNotification>> watchServerNotifications() {
    if (!_firebaseReady) {
      return Stream.value(const <InboxNotification>[]);
    }

    return _db.collection('notification').snapshots().asyncMap((snapshot) async {
      final out = <InboxNotification>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final hasTitle = _hasAnyTitle(data);
          final hasBody = _hasAnyBody(data);
          if (hasTitle || hasBody) {
            out.add(InboxNotification.fromDateDocument(doc));
          } else {
            final sub = await doc.reference.collection('items').get();
            for (final item in sub.docs) {
              out.add(InboxNotification.fromItemDocument(doc.id, item));
            }
          }
        } catch (e, st) {
          debugPrint('[notifications] skip doc ${doc.id}: $e\n$st');
        }
      }
      out.sort((a, b) => b.sortTime.compareTo(a.sortTime));
      return out;
    });
  }

  static bool _hasAnyTitle(Map<String, dynamic> d) {
    for (final k in ['title', 'heading', 'subject']) {
      final v = d[k]?.toString().trim();
      if (v != null && v.isNotEmpty) return true;
    }
    return false;
  }

  static bool _hasAnyBody(Map<String, dynamic> d) {
    for (final k in ['body', 'message', 'description']) {
      final v = d[k]?.toString().trim();
      if (v != null && v.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> deleteNotification(InboxNotification item) async {
    if (!item.canDeleteOnServer) return;
    await item.firestoreRef!.delete();
  }
}
