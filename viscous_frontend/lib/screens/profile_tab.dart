import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_state.dart';
import '../models/login_response.dart';
import '../services/profile_service.dart';
import '../services/storage_service.dart';

// ─── Theme-resolved helpers ────────────────────────────────────────────────────
Color _primary(BuildContext ctx) => Theme.of(ctx).colorScheme.primary;
Color _amber(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark
    ? const Color(0xFFFFB930)
    : const Color(0xFFD97706);
Color _red(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark
    ? const Color(0xFFFF4D6D)
    : const Color(0xFFDC2626);
Color _green(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark
    ? const Color(0xFF00E676)
    : const Color(0xFF059669);
Color _textDim(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark
    ? const Color(0xFF5A6A90)
    : const Color(0xFF64748B);

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> {
  final StorageService _storageService = StorageService();
  final ProfileService _profileService = ProfileService();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _stopController = TextEditingController();
  final _quietStartController = TextEditingController(text: '22:00');
  final _quietEndController = TextEditingController(text: '06:00');
  User? _user;
  bool _loading = true;
  bool _saving = false;
  bool _notifyReached = true;
  bool _notifyEta = true;
  bool _notifyOneStopAway = true;
  bool _notifyRouteLastStop = true;
  bool _notifyBusStarted = true;
  bool _quietHoursEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile({bool showLoader = true}) async {
    if (showLoader) setState(() => _loading = true);
    try {
      final local = await _storageService.getLoginData();
      if (local?.user != null) _applyUser(local!.user!);
      final remote = await _profileService.getMyProfile();
      _applyUser(remote);
      await _storageService.updateStoredUser(remote);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to load profile.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted && showLoader) setState(() => _loading = false);
    }
  }

  Future<void> _onPullRefresh() async {
    await Future.wait([
      ref.read(trackingProvider.notifier).refreshTracking(),
      _loadProfile(showLoader: false),
    ]);
  }

  void _applyUser(User user) {
    _user = user;
    _nameController.text = user.name ?? '';
    _emailController.text = user.email ?? '';
    _phoneController.text = user.phone ?? '';
    _stopController.text = user.userstop ?? '';
    final prefs = user.notificationPreferences ?? {};
    final quiet = user.notificationQuietHours ?? {};
    _notifyReached = prefs['notifyReached'] is bool
        ? prefs['notifyReached'] as bool
        : true;
    _notifyEta = prefs['notifyEta'] is bool ? prefs['notifyEta'] as bool : true;
    _notifyOneStopAway = prefs['notifyOneStopAway'] is bool
        ? prefs['notifyOneStopAway'] as bool
        : true;
    _notifyRouteLastStop = prefs['notifyRouteLastStop'] is bool
        ? prefs['notifyRouteLastStop'] as bool
        : true;
    _notifyBusStarted = prefs['notifyBusStarted'] is bool
        ? prefs['notifyBusStarted'] as bool
        : true;
    _quietHoursEnabled = quiet['enabled'] is bool
        ? quiet['enabled'] as bool
        : false;
    _quietStartController.text = (quiet['start'] ?? '22:00').toString();
    _quietEndController.text = (quiet['end'] ?? '06:00').toString();
  }

  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    try {
      final updated = await _profileService.updateMyProfile(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        userstop: _stopController.text.trim(),
        notificationPreferences: {
          'notifyReached': _notifyReached,
          'notifyEta': _notifyEta,
          'notifyOneStopAway': _notifyOneStopAway,
          'notifyRouteLastStop': _notifyRouteLastStop,
          'notifyBusStarted': _notifyBusStarted,
        },
        notificationQuietHours: {
          'enabled': _quietHoursEnabled,
          'start': _quietStartController.text.trim(),
          'end': _quietEndController.text.trim(),
          'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        },
      );
      _applyUser(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated ✓'),
            backgroundColor: _green(context),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update profile.'),
            backgroundColor: _red(context),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Sign Out?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text('You will be returned to the login screen.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: _textDim(ctx))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Sign Out',
                style: TextStyle(color: _red(ctx), fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _storageService.clearLoginData();
    ref.read(authStateProvider.notifier).state = false;
    if (mounted) context.go('/login');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _stopController.dispose();
    _quietStartController.dispose();
    _quietEndController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final tracking = ref.watch(trackingProvider);
    final displayRoute =
        tracking.routeMeta?.routeNumber ?? _user?.route ?? 'No route';

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: _loading
            ? Center(
                child: CircularProgressIndicator(
                  color: theme.colorScheme.primary,
                ),
              )
            : RefreshIndicator(
                color: theme.colorScheme.primary,
                onRefresh: _onPullRefresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    // ── Profile header ──────────────────────────────────────
                    _ProfileHeader(
                      user: _user,
                      displayRoute: displayRoute,
                      isDark: isDark,
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Account fields ──────────────────────────────
                          _SectionLabel('ACCOUNT INFO'),
                          _ProfileField(
                            label: 'Full Name',
                            controller: _nameController,
                            icon: Icons.person_rounded,
                          ),
                          const SizedBox(height: 10),
                          _ProfileField(
                            label: 'Email Address',
                            controller: _emailController,
                            icon: Icons.email_rounded,
                            inputType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 10),
                          _ProfileField(
                            label: 'Phone Number',
                            controller: _phoneController,
                            icon: Icons.phone_rounded,
                            inputType: TextInputType.phone,
                          ),
                          const SizedBox(height: 10),
                          _ProfileField(
                            label: 'Bus Stop',
                            controller: _stopController,
                            icon: Icons.location_on_rounded,
                          ),

                          const SizedBox(height: 20),

                          // ── Assigned route ──────────────────────────────
                          _SectionLabel('ASSIGNED ROUTE'),
                          _InfoCard(
                            icon: Icons.alt_route_rounded,
                            iconColor: _primary(context),
                            title: displayRoute,
                            subtitle: _user?.college ?? '-',
                          ),

                          const SizedBox(height: 20),

                          // ── Settings ────────────────────────────────────
                          _SectionLabel('PREFERENCES & SETTINGS'),

                          // Theme selector (System / Light / Dark)
                          _ThemeSelector(),

                          const SizedBox(height: 10),
                          _InfoCard(
                            icon: Icons.notifications_active_rounded,
                            iconColor: _amber(context),
                            title: 'Notification preferences',
                            subtitle: 'Customize alerts by event type',
                          ),
                          const SizedBox(height: 10),
                          _NotificationToggleTile(
                            title: 'Reached my stop',
                            value: _notifyReached,
                            onChanged: (v) =>
                                setState(() => _notifyReached = v),
                          ),
                          _NotificationToggleTile(
                            title: 'ETA alerts',
                            value: _notifyEta,
                            onChanged: (v) => setState(() => _notifyEta = v),
                          ),
                          _NotificationToggleTile(
                            title: 'One-stop-away alerts',
                            value: _notifyOneStopAway,
                            onChanged: (v) =>
                                setState(() => _notifyOneStopAway = v),
                          ),
                          _NotificationToggleTile(
                            title: 'Last stop alerts',
                            value: _notifyRouteLastStop,
                            onChanged: (v) =>
                                setState(() => _notifyRouteLastStop = v),
                          ),
                          _NotificationToggleTile(
                            title: 'Bus started alerts',
                            value: _notifyBusStarted,
                            onChanged: (v) =>
                                setState(() => _notifyBusStarted = v),
                          ),
                          const SizedBox(height: 10),
                          _InfoCard(
                            icon: Icons.bedtime_rounded,
                            iconColor: _textDim(context),
                            title: 'Quiet hours',
                            subtitle:
                                'Mute non-critical alerts in selected time range',
                          ),
                          const SizedBox(height: 10),
                          _NotificationToggleTile(
                            title: 'Enable quiet hours',
                            value: _quietHoursEnabled,
                            onChanged: (v) =>
                                setState(() => _quietHoursEnabled = v),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _ProfileField(
                                  label: 'Quiet Start (HH:mm)',
                                  controller: _quietStartController,
                                  icon: Icons.nightlight_round,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _ProfileField(
                                  label: 'Quiet End (HH:mm)',
                                  controller: _quietEndController,
                                  icon: Icons.wb_sunny_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _InfoCard(
                            icon: Icons.emergency_rounded,
                            iconColor: _red(context),
                            title: 'Emergency contacts',
                            subtitle:
                                'Driver: +91 9000000001  •  School: +91 9000000002',
                          ),

                          const SizedBox(height: 24),

                          // ── Save button ─────────────────────────────────
                          _SaveButton(saving: _saving, onSave: _saveProfile),

                          const SizedBox(height: 16),

                          // ── Logout button ───────────────────────────────
                          _LogoutButton(onLogout: _logout),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _NotificationToggleTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _NotificationToggleTile({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ─── Profile header ────────────────────────────────────────────────────────────
class _ProfileHeader extends StatelessWidget {
  final User? user;
  final String displayRoute;
  final bool isDark;
  const _ProfileHeader({
    required this.user,
    required this.displayRoute,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 36),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF0D1940), Color(0xFF080D22)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : LinearGradient(
                colors: [const Color(0xFF1D4ED8), const Color(0xFF3B82F6)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.2 : 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 2.5,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF00E676)
                        : const Color(0xFF059669),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF080D22)
                          : const Color(0xFF1D4ED8),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            user?.name ?? 'User',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${user?.role?.toUpperCase() ?? "STUDENT"}  •  $displayRoute',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Theme selector (3-way: System / Light / Dark) ────────────────────────────
class _ThemeSelector extends ConsumerWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(themeModeProvider);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    final options = [
      (ThemeMode.system, Icons.brightness_auto_rounded, 'System'),
      (ThemeMode.light, Icons.light_mode_rounded, 'Light'),
      (ThemeMode.dark, Icons.dark_mode_rounded, 'Dark'),
    ];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: options.map((opt) {
          final (mode, icon, label) = opt;
          final isSelected = current == mode;
          return Expanded(
            child: GestureDetector(
              onTap: () => ref.read(themeModeProvider.notifier).state = mode,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: primary.withValues(alpha: 0.3))
                      : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: isSelected ? primary : _textDim(context),
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? primary : _textDim(context),
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Save button ──────────────────────────────────────────────────────────────
class _SaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;
  const _SaveButton({required this.saving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: saving
              ? null
              : LinearGradient(
                  colors: [
                    primary,
                    isDark ? const Color(0xFF0099CC) : const Color(0xFF2563EB),
                  ],
                ),
          color: saving ? theme.dividerColor : null,
          boxShadow: saving
              ? []
              : [
                  BoxShadow(
                    color: primary.withValues(alpha: isDark ? 0.4 : 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: ElevatedButton(
          onPressed: saving ? null : onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: saving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_rounded, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'SAVE PROFILE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Logout button ────────────────────────────────────────────────────────────
class _LogoutButton extends StatelessWidget {
  final VoidCallback onLogout;
  const _LogoutButton({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final red = _red(context);
    return GestureDetector(
      onTap: onLogout,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: red.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, color: red, size: 18),
            const SizedBox(width: 10),
            Text(
              'SIGN OUT',
              style: TextStyle(
                color: red,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Profile field ────────────────────────────────────────────────────────────
class _ProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType inputType;

  const _ProfileField({
    required this.label,
    required this.controller,
    required this.icon,
    this.inputType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return TextField(
      controller: controller,
      keyboardType: inputType,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 14),
      cursorColor: primary,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: _textDim(context), fontSize: 13),
        prefixIcon: Icon(icon, color: primary, size: 19),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        filled: true,
        fillColor: theme.colorScheme.surface,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: primary, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4, left: 4),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: _primary(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: _primary(context),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info card ────────────────────────────────────────────────────────────────
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          if (theme.brightness == Brightness.light)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: iconColor.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(color: _textDim(context), fontSize: 11),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: _textDim(context), size: 18),
        ],
      ),
    );
  }
}
