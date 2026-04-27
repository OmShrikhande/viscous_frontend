import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_state.dart';

// ─── Constants ────────────────────────────────────────────────────────────
const Color _kCyan    = Color(0xFF00D4FF);
const Color _kAmber   = Color(0xFFFFB930);
const Color _kRed     = Color(0xFFFF4D6D);

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});
  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  String _selectedRoute = 'Green Line';
  final List<String> _routes = ['Green Line', 'Blue Line', 'Orange Line'];

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textDim = isDark ? const Color(0xFF5A6A90) : const Color(0xFF64748B);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── Header gradient ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                    ? [const Color(0xFF0D1940), const Color(0xFF080D22)]
                    : [const Color(0xFFE2E8F0), const Color(0xFFF8FAFC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [_kCyan.withOpacity(0.2), Colors.transparent],
                          ),
                        ),
                      ),
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: theme.colorScheme.surface,
                          border: Border.all(color: _kCyan.withOpacity(0.5), width: 2.5),
                          boxShadow: [
                            BoxShadow(color: _kCyan.withOpacity(0.25), blurRadius: 20)
                          ],
                        ),
                        child: const Icon(Icons.person_rounded, size: 42, color: _kCyan),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('Sarah Lee',
                      style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color, 
                        fontSize: 20, 
                        fontWeight: FontWeight.w800
                      )),
                  const SizedBox(height: 4),
                  Text('Parent Account  •  Route #42',
                      style: TextStyle(color: textDim, fontSize: 12)),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Section: Family ───────────────────────────────────
                  const _SectionLabel('FAMILY'),
                  _InfoCard(
                    icon: Icons.person_rounded,
                    iconColor: _kCyan,
                    title: 'Parent',
                    subtitle: 'Sarah Lee  •  +91 9000000000',
                  ),
                  const SizedBox(height: 10),
                  _InfoCard(
                    icon: Icons.child_care_rounded,
                    iconColor: _kAmber,
                    title: 'Child',
                    subtitle: 'Ethan Lee  •  Stop: Maple Residency',
                  ),

                  const SizedBox(height: 20),
                  // ── Section: Route ────────────────────────────────────
                  const _SectionLabel('ASSIGNED ROUTE'),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _kCyan.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.alt_route_rounded, color: _kCyan, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Assigned route',
                                  style: TextStyle(color: textDim, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(_selectedRoute,
                                  style: TextStyle(
                                    color: theme.textTheme.bodyLarge?.color, 
                                    fontSize: 14, 
                                    fontWeight: FontWeight.w700
                                  )),
                            ],
                          ),
                        ),
                        // Route dropdown
                        PopupMenuButton<String>(
                          onSelected: (v) => setState(() => _selectedRoute = v),
                          color: theme.colorScheme.surface,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
                          icon: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _kCyan.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: _kCyan.withOpacity(0.3)),
                            ),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('Change', style: TextStyle(color: _kCyan, fontSize: 11, fontWeight: FontWeight.w600)),
                              SizedBox(width: 4),
                              Icon(Icons.expand_more_rounded, color: _kCyan, size: 14),
                            ]),
                          ),
                          itemBuilder: (_) => _routes.map((r) => PopupMenuItem<String>(
                                value: r,
                                child: Text(r, style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 13)),
                              )).toList(),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  // ── Section: Preferences & Emergency ─────────────────
                  const _SectionLabel('PREFERENCES & SETTINGS'),
                  // Theme switch
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    child: SwitchListTile(
                      title: Text('DARK MODE', 
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color, 
                            fontSize: 13, 
                            fontWeight: FontWeight.w700
                          )),
                      subtitle: Text('Enable deep space appearance', 
                          style: TextStyle(color: textDim, fontSize: 11)),
                      secondary: const Icon(Icons.palette_rounded, color: _kCyan, size: 20),
                      activeColor: _kCyan,
                      value: ref.watch(themeModeProvider) == ThemeMode.dark,
                      onChanged: (val) {
                        ref.read(themeModeProvider.notifier).state = 
                            val ? ThemeMode.dark : ThemeMode.light;
                      },
                    ),
                  ),
                  _InfoCard(
                    icon: Icons.notifications_active_rounded,
                    iconColor: _kAmber,
                    title: 'Notification preferences',
                    subtitle: 'Arrival · Delays · Emergencies · Admin alerts',
                  ),
                  const SizedBox(height: 10),
                  _InfoCard(
                    icon: Icons.emergency_rounded,
                    iconColor: _kRed,
                    title: 'Emergency contacts',
                    subtitle: 'Driver: +91 9000000001  •  School: +91 9000000002',
                  ),

                  const SizedBox(height: 32),
                  // ── Logout button ─────────────────────────────────────
                  GestureDetector(
                    onTap: () {
                      ref.read(authStateProvider.notifier).state = false;
                      context.go('/login');
                    },
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _kRed.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _kRed.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: _kRed, size: 18),
                          SizedBox(width: 10),
                          Text('SIGN OUT',
                              style: TextStyle(color: _kRed, fontSize: 14,
                                  fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4, left: 4),
      child: Text(text,
          style: const TextStyle(color: _kCyan, fontSize: 10,
              fontWeight: FontWeight.w800, letterSpacing: 1.6)),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textDim = theme.brightness == Brightness.dark ? const Color(0xFF5A6A90) : const Color(0xFF64748B);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color, 
                      fontSize: 13, 
                      fontWeight: FontWeight.w700
                    )),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: TextStyle(color: textDim, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
