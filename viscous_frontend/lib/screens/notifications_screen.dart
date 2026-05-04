import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/inbox_notification.dart';
import '../providers/inbox_notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverAsync = ref.watch(serverNotificationsStreamProvider);
    final welcomeDismissed = ref.watch(welcomeDismissedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go('/app'),
        ),
      ),
      body: serverAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _NotificationListWithBanner(
          serverItems: const [],
          welcomeDismissed: welcomeDismissed,
          errorMessage: e.toString(),
          onRetry: () => ref.invalidate(serverNotificationsStreamProvider),
        ),
        data: (serverItems) => _NotificationListWithBanner(
          serverItems: serverItems,
          welcomeDismissed: welcomeDismissed,
          errorMessage: null,
          onRetry: () => ref.invalidate(serverNotificationsStreamProvider),
        ),
      ),
    );
  }
}

class _NotificationListWithBanner extends StatelessWidget {
  final List<InboxNotification> serverItems;
  final bool welcomeDismissed;
  final String? errorMessage;
  final VoidCallback onRetry;

  const _NotificationListWithBanner({
    required this.serverItems,
    required this.welcomeDismissed,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <InboxNotification>[
      if (!welcomeDismissed) InboxNotification.welcome(),
      ...serverItems,
    ];

    if (items.isEmpty && errorMessage == null) {
      return Center(
        child: Text(
          'No notifications yet.',
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.outline),
        ),
      );
    }

    return Column(
      children: [
        if (errorMessage != null)
          Material(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Could not sync from Firestore. Check rules and network.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onErrorContainer),
                    ),
                  ),
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (context, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return _DismissibleNotificationTile(item: item);
            },
          ),
        ),
      ],
    );
  }
}

class _DismissibleNotificationTile extends ConsumerWidget {
  final InboxNotification item;

  const _DismissibleNotificationTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      confirmDismiss: (direction) => _onConfirmDismiss(context, ref),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.dividerColor),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      item.isWelcome ? Icons.waving_hand_rounded : Icons.campaign_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (item.dateKey != null)
                      Text(
                        item.dateKey!,
                        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(item.body, style: theme.textTheme.bodyMedium),
                if (item.extraSummary != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    item.extraSummary!,
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline),
                  ),
                ],
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Swipe left to remove',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline.withValues(alpha: 0.85),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool?> _onConfirmDismiss(BuildContext context, WidgetRef ref) async {
    if (item.isWelcome) {
      await ref.read(welcomeDismissedProvider.notifier).setDismissed();
      return true;
    }
    try {
      await ref.read(notificationsFirestoreApiProvider).deleteNotification(item);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification removed')),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
      return false;
    }
  }
}
