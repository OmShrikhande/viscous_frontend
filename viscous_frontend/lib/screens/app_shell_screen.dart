import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import '../services/push_notification_service.dart';
import 'home_tab.dart';
import 'map_tab.dart';
import 'profile_tab.dart';

class AppShellScreen extends ConsumerStatefulWidget {
  const AppShellScreen({super.key});

  @override
  ConsumerState<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends ConsumerState<AppShellScreen> {
  static const _tabs = [HomeTab(), MapTab(), ProfileTab()];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      PushNotificationService.instance.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(currentTabProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _tabs[tab],
      bottomNavigationBar: _PremiumNavBar(
        currentIndex: tab,
        onTap: (i) => ref.read(currentTabProvider.notifier).state = i,
      ),
    );
  }
}

class _PremiumNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _PremiumNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    // Distinct background colours per mode
    final Color navBg = isDark ? const Color(0xFF0D1235) : Colors.white;
    final Color navBorder = isDark ? const Color(0xFF1E2A5A) : const Color(0xFFDCE6FA);
    final Color textDim = isDark ? const Color(0xFF4A5580) : const Color(0xFF94A3B8);

    final items = [
      (Icons.home_outlined, Icons.home_rounded, 'Home'),
      (Icons.map_outlined, Icons.map_rounded, 'Live Map'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
    ];

    return Container(
      height: 74,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: navBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.14 : 0.1),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final (inactiveIcon, activeIcon, label) = items[i];
          return _NavItem(
            icon: inactiveIcon,
            activeIcon: activeIcon,
            label: label,
            index: i,
            current: currentIndex,
            onTap: onTap,
            primary: primary,
            textDim: textDim,
            isDark: isDark,
          );
        }),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;
  final Color primary, textDim;
  final bool isDark;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    required this.primary,
    required this.textDim,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? primary.withValues(alpha: isDark ? 0.14 : 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isActive
              ? Border.all(color: primary.withValues(alpha: isDark ? 0.25 : 0.2))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: isActive ? primary : textDim,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? primary : textDim,
                letterSpacing: 0.4,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
