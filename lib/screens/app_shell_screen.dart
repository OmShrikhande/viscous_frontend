import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';
import 'home_tab.dart';
import 'map_tab.dart';
import 'profile_tab.dart';

class AppShellScreen extends ConsumerWidget {
  const AppShellScreen({super.key});

  static const _tabs = [HomeTab(), MapTab(), ProfileTab()];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
    
    final Color navBg     = isDark ? const Color(0xFF0D1235) : Colors.white;
    final Color navBorder = isDark ? const Color(0xFF1E2A5A) : const Color(0xFFE2E8F0);
    final Color cyan      = theme.colorScheme.primary;
    final Color textDim   = isDark ? const Color(0xFF4A5580) : const Color(0xFF64748B);

    return Container(
      height: 72,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: navBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: cyan.withOpacity(isDark ? 0.12 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(icon: Icons.home_outlined,   activeIcon: Icons.home_rounded,        label: 'Home',    index: 0, current: currentIndex, onTap: onTap, cyan: cyan, textDim: textDim),
          _NavItem(icon: Icons.map_outlined,    activeIcon: Icons.map_rounded,         label: 'Map',     index: 1, current: currentIndex, onTap: onTap, cyan: cyan, textDim: textDim),
          _NavItem(icon: Icons.person_outline,  activeIcon: Icons.person_rounded,      label: 'Profile', index: 2, current: currentIndex, onTap: onTap, cyan: cyan, textDim: textDim),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;
  final Color cyan, textDim;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.current,
    required this.onTap,
    required this.cyan,
    required this.textDim,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? cyan.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? cyan : textDim,
              size: 22,
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? cyan : textDim,
                letterSpacing: 0.6,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
