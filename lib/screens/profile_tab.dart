import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_state.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String selectedRoute = 'Green Line';
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              title: Text('Parent: Sarah Lee'),
              subtitle: Text('Mobile: +91 9000000000'),
            ),
          ),
          const Card(
            child: ListTile(
              title: Text('Child: Ethan Lee'),
              subtitle: Text('Assigned stop: Maple Residency'),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Assigned route'),
              subtitle: Text(selectedRoute),
              trailing: DropdownButton<String>(
                value: selectedRoute,
                items: const [
                  DropdownMenuItem(
                    value: 'Green Line',
                    child: Text('Green Line'),
                  ),
                  DropdownMenuItem(
                    value: 'Blue Line',
                    child: Text('Blue Line'),
                  ),
                  DropdownMenuItem(
                    value: 'Orange Line',
                    child: Text('Orange Line'),
                  ),
                ],
                onChanged: (_) {},
              ),
            ),
          ),
          const Card(
            child: ListTile(
              title: Text('Notification preferences'),
              subtitle: Text('Arrival, delays, emergencies, admin alerts'),
            ),
          ),
          const Card(
            child: ListTile(
              title: Text('Emergency contacts'),
              subtitle: Text('Driver: +91 9000000001 • School: +91 9000000002'),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {
              ref.read(authStateProvider.notifier).state = false;
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
