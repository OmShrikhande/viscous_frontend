import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app_state.dart';

// ─── Theme-resolved accent helpers ───────────────────────────────────────────
Color _accent(BuildContext ctx) => Theme.of(ctx).colorScheme.primary;
Color _amber(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark
    ? const Color(0xFFFFB930)
    : const Color(0xFFD97706);
Color _green(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark
    ? const Color(0xFF00E676)
    : const Color(0xFF059669);
Color _textDim(BuildContext ctx) => Theme.of(ctx).brightness == Brightness.dark
    ? const Color(0xFF5A6A90)
    : const Color(0xFF64748B);

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(trackingProvider);
    final theme = Theme.of(context);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            _HomeHeader(tracking: tracking),
            const SizedBox(height: 10),
            Expanded(
              child: RefreshIndicator(
                color: theme.colorScheme.primary,
                onRefresh: () =>
                    ref.read(trackingProvider.notifier).refreshTracking(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    children: [
                      // ── Route info card ───────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _GlassCard(
                          child: Row(
                            children: [
                              _RouteIconBox(context: context),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${tracking.routeMeta?.from ?? "Loading…"}  →  ${tracking.routeMeta?.to ?? "…"}',
                                      style: TextStyle(
                                        color: theme.textTheme.bodyLarge?.color,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${tracking.routeMeta?.routeNumber ?? "Route"}  •  ${tracking.routeMeta?.busId ?? "Bus ID"}',
                                      style: TextStyle(
                                        color: _textDim(context),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _LiveBadge(
                                isLive:
                                    tracking.isBusRunning &&
                                    !tracking.routeCompleted,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ── Stop status strip ─────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _StatusStrip(tracking: tracking),
                      ),

                      const SizedBox(height: 4),

                      // ── Timeline ──────────────────────────────────────
                      _TimelineSection(tracking: tracking),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Route icon box ───────────────────────────────────────────────────────────
class _RouteIconBox extends StatelessWidget {
  final BuildContext context;
  const _RouteIconBox({required this.context});

  @override
  Widget build(BuildContext ctx) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;
    final primary = Theme.of(ctx).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: isDark ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Icon(Icons.route_rounded, color: primary, size: 20),
    );
  }
}

// ─── Status strip ─────────────────────────────────────────────────────────────
class _StatusStrip extends StatelessWidget {
  final TrackingState tracking;
  const _StatusStrip({required this.tracking});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final green = _green(context);
    final amber = _amber(context);
    final running = tracking.isBusRunning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          if (theme.brightness == Brightness.light)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.flag_rounded, color: amber, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Current: ${tracking.currentStop}  •  Next: ${tracking.nextStop}\nConfidence: ${tracking.confidenceScore}% (${tracking.confidenceLevel.toUpperCase()})',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _StatusChip(running: running, green: green, amber: amber),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool running;
  final Color green, amber;
  const _StatusChip({
    required this.running,
    required this.green,
    required this.amber,
  });

  @override
  Widget build(BuildContext context) {
    final color = running ? green : amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        running ? 'RUNNING' : 'STOPPED',
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─── Timeline ─────────────────────────────────────────────────────────────────
const double _kTimelineRowHeight = 140;

class _TimelineSection extends StatelessWidget {
  final TrackingState tracking;
  const _TimelineSection({required this.tracking});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Vertical road strip
        Positioned(
          top: 0,
          bottom: 0,
          left: MediaQuery.of(context).size.width / 2 - 10,
          child: SizedBox(
            width: 20,
            child: CustomPaint(painter: _RoadPainter(theme: theme)),
          ),
        ),

        // Stop rows
        Column(
          children: List.generate(tracking.stops.length, (i) {
            final stop = tracking.stops[i];
            final isCurrent = i == tracking.currentDisplayIndex;
            final isPast = i < tracking.currentDisplayIndex;
            return SizedBox(
              height: _kTimelineRowHeight,
              child: _TimelineRow(
                stop: stop,
                isLeft: i.isEven,
                isCurrent: isCurrent,
                isPast: isPast,
                etaLabel: i == tracking.nextStopIndex
                    ? tracking.etaLabel
                    : null,
                tracking: tracking,
              ),
            );
          }),
        ),

        // Moving bus (on top) — `top` is interpolated by progressToNextStop
        // so the bus glides smoothly between stops instead of teleporting.
        if (tracking.stops.isNotEmpty)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 140),
            curve: Curves.linear,
            top:
                (tracking.currentDisplayIndex + tracking.progressToNextStop) *
                    _kTimelineRowHeight +
                38,
            left: MediaQuery.of(context).size.width / 2 - 20,
            child: _BusOnRoad(isMoving: tracking.isBusRunning),
          ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final BusStop stop;
  final bool isLeft, isCurrent, isPast;
  final String? etaLabel;
  final TrackingState tracking;

  const _TimelineRow({
    required this.stop,
    required this.isLeft,
    required this.isCurrent,
    required this.isPast,
    required this.tracking,
    this.etaLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final green = _green(context);
    final accent = _accent(context);
    final dim = _textDim(context);
    final statusColor = isCurrent ? green : (isPast ? accent : dim);

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: isLeft
                ? _StopCard(
                    stop: stop,
                    isLeft: true,
                    color: statusColor,
                    etaLabel: etaLabel,
                  )
                : const SizedBox.shrink(),
          ),
          // Center node
          SizedBox(
            width: 80,
            height: 28,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: isLeft ? 10 : 40,
                  right: isLeft ? 40 : 10,
                  child: Container(
                    height: 2,
                    color: statusColor.withValues(alpha: 0.55),
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF080D22) : Colors.white,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(
                          alpha: isDark ? 0.7 : 0.4,
                        ),
                        blurRadius: isDark ? 14 : 8,
                        spreadRadius: isDark ? 2 : 0,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: !isLeft
                ? _StopCard(
                    stop: stop,
                    isLeft: false,
                    color: statusColor,
                    etaLabel: etaLabel,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  final BusStop stop;
  final bool isLeft;
  final Color color;
  final String? etaLabel;

  const _StopCard({
    required this.stop,
    required this.isLeft,
    required this.color,
    this.etaLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final amber = _amber(context);
    return Container(
      margin: EdgeInsets.only(left: isLeft ? 12 : 0, right: isLeft ? 0 : 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: isDark ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isLeft
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isLeft) const Spacer(),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  stop.name,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  softWrap: true,
                ),
              ),
              if (isLeft) const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          if (etaLabel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: amber.withValues(alpha: 0.45)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded, color: amber, size: 11),
                  const SizedBox(width: 4),
                  Text(
                    'ETA  $etaLabel',
                    style: TextStyle(
                      color: amber,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Scheduled',
              style: TextStyle(color: _textDim(context), fontSize: 11),
            ),
        ],
      ),
    );
  }
}

// ─── Road painter ─────────────────────────────────────────────────────────────
class _RoadPainter extends CustomPainter {
  final ThemeData theme;
  _RoadPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final bool isDark = theme.brightness == Brightness.dark;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = isDark ? const Color(0xFF1E2540) : const Color(0xFFCBD5E1),
    );
    final dash = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.35)
          : Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 1.5;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, y + 8),
        dash,
      );
      y += 16;
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) =>
      old.theme.brightness != theme.brightness;
}

// ─── Custom school bus (front view) on the road ───────────────────────────────
class _BusOnRoad extends StatefulWidget {
  final bool isMoving;
  const _BusOnRoad({required this.isMoving});

  @override
  State<_BusOnRoad> createState() => _BusOnRoadState();
}

class _BusOnRoadState extends State<_BusOnRoad>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Tiny vertical bob while moving — sells "the bus is rolling".
        final bob = widget.isMoving
            ? (math.sin(_ctrl.value * math.pi * 2) * 0.8)
            : 0.0;
        return Transform.translate(
          offset: Offset(0, bob),
          child: CustomPaint(
            painter: _SchoolBusFrontPainter(
              anim: _ctrl.value,
              isMoving: widget.isMoving,
            ),
            size: const Size(46, 64),
          ),
        );
      },
    );
  }
}

class _SchoolBusFrontPainter extends CustomPainter {
  final double anim;
  final bool isMoving;
  const _SchoolBusFrontPainter({required this.anim, required this.isMoving});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Soft motion glow under the bus when moving ─────────────────────────
    if (isMoving) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(w / 2, h * 0.97),
          width: w * 1.05,
          height: 11,
        ),
        Paint()
          ..color = const Color(0xFFFFC73E).withValues(alpha: 0.28 + 0.18 * anim)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
      );
    }

    // ── Drop shadow ─────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(2, h * 0.13 + 5, w - 4, h * 0.79),
        topLeft: const Radius.circular(11),
        topRight: const Radius.circular(11),
        bottomLeft: const Radius.circular(6),
        bottomRight: const Radius.circular(6),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // ── Body — school bus amber, with subtle vertical gradient ─────────────
    final bodyRect = Rect.fromLTWH(1, h * 0.13, w - 2, h * 0.79);
    final body = RRect.fromRectAndCorners(
      bodyRect,
      topLeft: const Radius.circular(11),
      topRight: const Radius.circular(11),
      bottomLeft: const Radius.circular(6),
      bottomRight: const Radius.circular(6),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFFFC035), Color(0xFFE48800)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(bodyRect),
    );

    // ── Body highlight (top-left gloss) ────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(2, h * 0.13, w * 0.45, h * 0.28),
        topLeft: const Radius.circular(11),
        topRight: const Radius.circular(8),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );

    // ── Safety stripe (black) ──────────────────────────────────────────────
    canvas.drawRect(
      Rect.fromLTWH(1, h * 0.32, w - 2, h * 0.085),
      Paint()..color = const Color(0xFF111418),
    );
    // Reflective sub-stripe
    canvas.drawRect(
      Rect.fromLTWH(1, h * 0.405, w - 2, h * 0.012),
      Paint()..color = const Color(0xFFFFE9A8),
    );

    // ── Windshield ─────────────────────────────────────────────────────────
    final winRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.1, h * 0.05, w * 0.8, h * 0.22),
      topLeft: const Radius.circular(7),
      topRight: const Radius.circular(7),
      bottomLeft: const Radius.circular(2),
      bottomRight: const Radius.circular(2),
    );
    canvas.drawRRect(
      winRect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE5F1FF), Color(0xFF6FA8E0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(winRect.outerRect),
    );
    // Windshield divider
    canvas.drawLine(
      Offset(w * 0.5, h * 0.06),
      Offset(w * 0.5, h * 0.265),
      Paint()
        ..color = const Color(0xFF111418).withValues(alpha: 0.55)
        ..strokeWidth = 1.2,
    );
    // Windshield shine
    canvas.drawLine(
      Offset(w * 0.18, h * 0.07),
      Offset(w * 0.18, h * 0.24),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // ── "SCHOOL BUS" label badge on safety stripe ──────────────────────────
    final tp =
        ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: TextAlign.center))
          ..pushStyle(
            ui.TextStyle(
              color: const Color(0xFFFFE9A8),
              fontSize: 6.2,
              fontWeight: ui.FontWeight.w900,
              letterSpacing: 0.9,
            ),
          )
          ..addText('SCHOOL BUS');
    final para = tp.build()..layout(ui.ParagraphConstraints(width: w));
    canvas.drawParagraph(para, Offset(0, h * 0.46));

    // ── Side mirrors ───────────────────────────────────────────────────────
    final mirrorPaint = Paint()..color = const Color(0xFF1F2430);
    canvas.drawRect(Rect.fromLTWH(-1, h * 0.18, 4, h * 0.05), mirrorPaint);
    canvas.drawRect(Rect.fromLTWH(w - 3, h * 0.18, 4, h * 0.05), mirrorPaint);

    // ── Front grille ───────────────────────────────────────────────────────
    final grilleRect = Rect.fromLTWH(w * 0.2, h * 0.62, w * 0.6, h * 0.08);
    canvas.drawRRect(
      RRect.fromRectAndRadius(grilleRect, const Radius.circular(2)),
      Paint()..color = const Color(0xFF111418),
    );
    // Grille slats
    final slatPaint = Paint()
      ..color = const Color(0xFFFFE9A8).withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    for (var i = 1; i < 5; i++) {
      final y = grilleRect.top + grilleRect.height * (i / 5);
      canvas.drawLine(
        Offset(grilleRect.left + 1, y),
        Offset(grilleRect.right - 1, y),
        slatPaint,
      );
    }

    // ── Bumper ─────────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.08, h * 0.78, w * 0.84, h * 0.06),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF1F2430),
    );

    // ── Headlights with halo ───────────────────────────────────────────────
    final hlGlow = Paint()
      ..color = const Color(0xFFFFF3B0).withValues(alpha: 0.4 + 0.35 * anim)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 + 3 * anim);
    canvas.drawCircle(Offset(w * 0.22, h * 0.86), 6, hlGlow);
    canvas.drawCircle(Offset(w * 0.78, h * 0.86), 6, hlGlow);
    canvas.drawCircle(
      Offset(w * 0.22, h * 0.86),
      3.6,
      Paint()..color = const Color(0xFFFFF3B0),
    );
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.86),
      3.6,
      Paint()..color = const Color(0xFFFFF3B0),
    );

    // ── Emergency roof lights (red / blue alternating) ─────────────────────
    final redAlpha = 0.5 + 0.5 * anim;
    final blueAlpha = 0.5 + 0.5 * (1 - anim);
    canvas.drawCircle(
      Offset(w * 0.32, h * 0.07),
      3.2,
      Paint()
        ..color = const Color(0xFFEF4444).withValues(alpha: redAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * anim),
    );
    canvas.drawCircle(
      Offset(w * 0.68, h * 0.07),
      3.2,
      Paint()
        ..color = const Color(0xFF60A5FA).withValues(alpha: blueAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * (1 - anim)),
    );

    // ── Wheels — visible at the bottom corners (front view perspective) ────
    final wheelY = h * 0.93;
    final wheelOuter = Paint()..color = const Color(0xFF111418);
    final wheelRim = Paint()..color = const Color(0xFFB6BFD2);
    canvas.drawCircle(Offset(w * 0.16, wheelY), 3.6, wheelOuter);
    canvas.drawCircle(Offset(w * 0.84, wheelY), 3.6, wheelOuter);
    canvas.drawCircle(Offset(w * 0.16, wheelY), 1.8, wheelRim);
    canvas.drawCircle(Offset(w * 0.84, wheelY), 1.8, wheelRim);
  }

  @override
  bool shouldRepaint(covariant _SchoolBusFrontPainter old) =>
      old.anim != anim || old.isMoving != isMoving;
}

// ─── Header ────────────────────────────────────────────────────────────────────
class _HomeHeader extends ConsumerWidget {
  final TrackingState tracking;
  const _HomeHeader({required this.tracking});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final amber = _amber(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF001845), Color(0xFF002366)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [const Color(0xFF1D4ED8), const Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: isDark ? 0.25 : 0.3),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // Shield icon
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.shield_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tracking.routeMeta?.college.toUpperCase() ??
                      'VISCOUS TRACKER',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Safe & Live Bus Tracking',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push('/app/notifications'),
            icon: Icon(
              Icons.notifications_active_rounded,
              color: amber,
              size: 24,
            ),
            tooltip: 'Notifications',
          ),
          IconButton(
            onPressed: () => ref.read(currentTabProvider.notifier).state = 2,
            icon: const Icon(
              Icons.account_circle_rounded,
              color: Colors.white70,
              size: 28,
            ),
            tooltip: 'Profile',
          ),
        ],
      ),
    );
  }
}

// ─── Live badge ────────────────────────────────────────────────────────────────
class _LiveBadge extends StatefulWidget {
  final bool isLive;
  const _LiveBadge({required this.isLive});

  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLive) return const SizedBox.shrink();
    final green = _green(context);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: green.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: green.withValues(alpha: 0.6 + 0.4 * _ctrl.value),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              'LIVE',
              style: TextStyle(
                color: green,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Glass card ────────────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.07),
            blurRadius: isDark ? 20 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
