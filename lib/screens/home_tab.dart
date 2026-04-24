import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(trackingProvider);
    final miniTab = ref.watch(homeMiniTabProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Parent: Sarah Lee\nChild: Ethan Lee\nRoute: Green Line\nBus: KA-01-BT-204',
                            style: TextStyle(height: 1.4),
                          ),
                        ),
                        SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 0, label: Text('ETA')),
                            ButtonSegment(value: 1, label: Text('Admin')),
                            ButtonSegment(value: 2, label: Text('Map')),
                          ],
                          selected: {miniTab},
                          onSelectionChanged: (s) {
                            final value = s.first;
                            ref.read(homeMiniTabProvider.notifier).state =
                                value;
                            if (value == 2) {
                              ref.read(currentTabProvider.notifier).state = 1;
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (miniTab == 0)
                      Text(
                        'Next ETA: ${tracking.etaToNextMinutes} mins • Delay: ${tracking.delayMinutes} mins',
                      )
                    else if (miniTab == 1)
                      const Text(
                        'Admin: Driver delayed by 2 mins due to traffic.',
                      )
                    else
                      const Text('Switching to map...'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _SmartAlertBanner(tracking: tracking),
            const SizedBox(height: 12),
            Expanded(
              child: Card(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: tracking.stops.length,
                  itemBuilder: (context, index) {
                    final isDone = index < tracking.currentStopIndex;
                    final isCurrent = index == tracking.currentStopIndex;
                    final color = isDone
                        ? const Color(0xFF16A34A)
                        : isCurrent
                        ? const Color(0xFFF59E0B)
                        : Colors.grey;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            Icon(
                              isCurrent ? Icons.directions_bus : Icons.circle,
                              size: 18,
                              color: color,
                            ),
                            if (index != tracking.stops.length - 1)
                              Container(
                                width: 2,
                                height: 34,
                                color: Colors.grey.shade300,
                              ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              tracking.stops[index].name,
                              style: TextStyle(
                                fontWeight: isCurrent
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Current: ${tracking.currentStop} • Next: ${tracking.nextStop} • Completion: ${tracking.completionPercent}% • Last updated: ${tracking.lastUpdated.hour}:${tracking.lastUpdated.minute.toString().padLeft(2, '0')}',
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartAlertBanner extends StatelessWidget {
  const _SmartAlertBanner({required this.tracking});

  final TrackingState tracking;

  @override
  Widget build(BuildContext context) {
    final left = tracking.stops.length - 1 - tracking.currentStopIndex;
    String text = 'Bus is on route.';
    if (tracking.routeCompleted) {
      text = 'Bus has reached destination.';
    } else if (!tracking.routeStarted) {
      text = 'Bus has not started yet.';
    } else if (left <= 1) {
      text = 'Bus is 1 stop away.';
    } else if (left == 2) {
      text = 'Bus is 2 stops away.';
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
