import 'package:cloud_firestore/cloud_firestore.dart';

/// One row in the in-app notification list (welcome tile or Firestore-backed).
class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.sortTime,
    required this.isWelcome,
    this.dateKey,
    this.extraSummary,
    this.firestoreRef,
  });

  static const welcomeId = '__welcome__';

  final String id;
  final String title;
  final String body;
  final DateTime sortTime;
  final bool isWelcome;
  final String? dateKey;
  final String? extraSummary;
  final DocumentReference<Map<String, dynamic>>? firestoreRef;

  static InboxNotification welcome() {
    return InboxNotification(
      id: welcomeId,
      title: 'Welcome to Viscous',
      body:
          'Track your bus in real time, get route updates, and stay informed. '
          'New announcements from your school will appear here as soon as they are published.',
      sortTime: DateTime.fromMillisecondsSinceEpoch(0),
      isWelcome: true,
      firestoreRef: null,
    );
  }

  static String? _firstNonEmptyString(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static DateTime _parseSortTime(Map<String, dynamic> data, String docId) {
    final raw = data['createdAt'] ?? data['time'] ?? data['timestamp'] ?? data['sentAt'];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    final parsed = DateTime.tryParse(docId);
    if (parsed != null) return parsed;
    return DateTime.now();
  }

  static String? _extraFromMap(Map<String, dynamic> data) {
    const skip = {'title', 'heading', 'subject', 'body', 'message', 'createdAt', 'time', 'timestamp', 'sentAt'};
    final parts = <String>[];
    data.forEach((k, v) {
      if (skip.contains(k)) return;
      if (v == null) return;
      final s = v.toString().trim();
      if (s.isEmpty || s.length > 120) return;
      parts.add('$k: $s');
    });
    if (parts.isEmpty) return null;
    return parts.take(3).join(' · ');
  }

  factory InboxNotification.fromDateDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final title = _firstNonEmptyString(data, const ['title', 'heading', 'subject']) ?? 'Update';
    final body = _firstNonEmptyString(data, const ['body', 'message', 'description']) ?? '';
    return InboxNotification(
      id: 'date:${doc.id}',
      title: title,
      body: body.isEmpty ? '(No message body)' : body,
      sortTime: _parseSortTime(data, doc.id),
      isWelcome: false,
      dateKey: doc.id,
      extraSummary: _extraFromMap(data),
      firestoreRef: doc.reference,
    );
  }

  factory InboxNotification.fromItemDocument(
    String dateKey,
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final title = _firstNonEmptyString(data, const ['title', 'heading', 'subject']) ?? 'Update';
    final body = _firstNonEmptyString(data, const ['body', 'message', 'description']) ?? '';
    return InboxNotification(
      id: 'item:${doc.reference.path}',
      title: title,
      body: body.isEmpty ? '(No message body)' : body,
      sortTime: _parseSortTime(data, doc.id),
      isWelcome: false,
      dateKey: dateKey,
      extraSummary: _extraFromMap(data),
      firestoreRef: doc.reference,
    );
  }

  bool get canDeleteOnServer => firestoreRef != null && !isWelcome;
}
