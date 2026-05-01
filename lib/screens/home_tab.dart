import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_state.dart';

// ─── Constants ────────────────────────────────────────────────────────────
const Color _kCyan    = Color(0xFF00D4FF);
const Color _kAmber   = Color(0xFFFFB930);
const Color _kGreen   = Color(0xFF00E676);

class HomeTab extends ConsumerWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking    = ref.watch(trackingProvider);
    final miniTab     = ref.watch(homeMiniTabProvider);
    final theme       = Theme.of(context);
    final isDark      = theme.brightness == Brightness.dark;
    
    final Color textDim = isDark ? const Color(0xFF5A6A90) : const Color(0xFF64748B);

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            _HomeHeader(tracking: tracking, textDim: textDim),
            
            // ── Search bar ────────────────────────────────────────────────
            _buildSearchBar(context, textDim),
            
            const SizedBox(height: 10),
            
            // ── Main scrollable content ───────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Control card
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _GlassCard(
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: _kCyan.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.directions_bus_rounded, color: _kCyan, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${tracking.routeData?.from ?? "Loading..."}  →  ${tracking.routeData?.to ?? "..."}',
                                          style: TextStyle(
                                            color: theme.textTheme.bodyLarge?.color, 
                                            fontWeight: FontWeight.w600, 
                                            fontSize: 13
                                          )),
                                      const SizedBox(height: 2),
                                      Text('${tracking.routeData?.routeNumber ?? "Route"}  •  ${tracking.routeData?.busId ?? "Bus ID"}',
                                          style: TextStyle(color: textDim, fontSize: 11)),
                                    ],
                                  ),
                                ),
                                _LiveBadge(isLive: tracking.routeStarted && !tracking.routeCompleted),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _PanelSegmentedBar(
                              value: miniTab,
                              textDim: textDim,
                              onChanged: (v) {
                                ref.read(homeMiniTabProvider.notifier).state = v;
                                if (v == 2) ref.read(currentTabProvider.notifier).state = 1;
                              },
                            ),
                            const SizedBox(height: 12),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _PanelContent(
                                key: ValueKey(miniTab), 
                                miniTab: miniTab, 
                                tracking: tracking,
                                textDim: textDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                   const SizedBox(height: 16),
                   
                   // ── Timeline ───────────────────────────────────────────────
                   _TimelineSection(tracking: tracking),
                   
                   const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, Color textDim) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          if (theme.brightness == Brightness.light)
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
           const Icon(Icons.my_location_rounded, color: Colors.blueAccent, size: 20),
           const SizedBox(width: 12),
           Expanded(
             child: TextField(
               style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 14),
               decoration: InputDecoration(
                 hintText: 'Search Bus Stop...',
                 hintStyle: TextStyle(color: textDim, fontSize: 14),
                 border: InputBorder.none,
               ),
             ),
           ),
           Icon(Icons.search, color: textDim, size: 20),
        ],
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  final TrackingState tracking;
  const _TimelineSection({required this.tracking});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // The vertical ROAD strip
        Positioned(
          top: 0,
          bottom: 0,
          child: Container(
            width: 20, 
            child: CustomPaint(
              painter: _RoadPainter(theme: theme),
            ),
          ),
        ),
        
        // Stops and Bus
        Column(
          children: List.generate(tracking.stops.length, (index) {
            final stop       = tracking.stops[index];
            final isCurrent  = index == tracking.currentStopIndex;
            final isPast     = index < tracking.currentStopIndex;
            final isLeft     = index % 2 == 0;
            
            return Column(
              children: [
                _TimelineRow(
                  stop: stop,
                  isLeft: isLeft,
                  isCurrent: isCurrent,
                  isPast: isPast,
                  eta: index == tracking.nextStopIndex ? tracking.etaToNextMinutes : null,
                  tracking: tracking,
                ),
                
                // Show bus between current and next
                if (isCurrent && !tracking.routeCompleted && tracking.routeStarted)
                  const _BusOnRoad(),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final BusStop stop;
  final bool isLeft, isCurrent, isPast;
  final int? eta;
  final TrackingState tracking;

  const _TimelineRow({
    required this.stop,
    required this.isLeft,
    required this.isCurrent,
    required this.isPast,
    required this.tracking,
    this.eta,
  });

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final isDark      = theme.brightness == Brightness.dark;
    final textDim     = isDark ? const Color(0xFF5A6A90) : const Color(0xFF64748B);
    final statusColor = isCurrent ? _kGreen : (isPast ? Colors.blueAccent : textDim);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left card space
          Expanded(
            flex: 1,
            child: isLeft 
              ? _StopCard(stop: stop, isLeft: true, color: statusColor, eta: eta, tracking: tracking)
              : const SizedBox.shrink(),
          ),
          
          // Center axis (Road Area)
          Container(
            width: 80, 
            height: 20, // Increased height to prevent clipping
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Horizontal connector line
                Positioned(
                  left: isLeft ? 10 : 40,
                  right: isLeft ? 40 : 10,
                  child: Container(
                    height: 2,
                    color: statusColor.withOpacity(0.6),
                  ),
                ),
                // Glowing solid dot sitting on the road
                Container(
                  width: 22, // Increased dot size to be visible
                  height: 22,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: statusColor.withOpacity(0.8), blurRadius: 15, spreadRadius: 3),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Right card space
          Expanded(
            flex: 1,
            child: !isLeft 
              ? _StopCard(stop: stop, isLeft: false, color: statusColor, eta: eta, tracking: tracking)
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
  final int? eta;
  final TrackingState tracking;

  const _StopCard({
    required this.stop, 
    required this.isLeft, 
    required this.color,
    required this.tracking,
    this.eta,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: EdgeInsets.only(
        left: isLeft ? 12 : 0,
        right: isLeft ? 0 : 12,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isLeft) const Spacer(),
              Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  stop.name,
                  style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color, 
                    fontSize: 14, 
                    fontWeight: FontWeight.bold
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isLeft) const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tracking.routeData != null 
                ? 'Arriving at ${tracking.routeData!.stops[tracking.stops.indexOf(stop)].time}'
                : (eta != null ? 'Bus - $eta min' : 'Scheduled'),
            style: TextStyle(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  final ThemeData theme;
  _RoadPainter({required this.theme});

  @override
  void paint(Canvas canvas, Size size) {
    final bool isDark = theme.brightness == Brightness.dark;
    
    // 1. Draw the asphalt strip
    var roadPaint = Paint()
      ..color = isDark ? const Color(0xFF1E2540).withOpacity(0.8) : const Color(0xFFD1D5DB)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), roadPaint);

    // 2. Draw the white dashed lane markings
    var dashPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.4) : Colors.black.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    var max = size.height;
    var dashWidth = 8.0;
    var dashSpace = 8.0;
    double startY = 0;
    
    while (startY < max) {
      canvas.drawLine(
        Offset(size.width / 2, startY), 
        Offset(size.width / 2, startY + dashWidth), 
        dashPaint
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _RoadPainter old) => old.theme.brightness != theme.brightness;
}

class _BusOnRoad extends StatefulWidget {
  const _BusOnRoad();
  @override
  State<_BusOnRoad> createState() => _BusOnRoadState();
}

class _BusOnRoadState extends State<_BusOnRoad> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80, 
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.2 * _controller.value),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_bus_rounded,
                color: _kGreen,
                size: 40 + (6 * _controller.value), 
                shadows: [
                  Shadow(color: _kGreen.withOpacity(0.8), blurRadius: 15 * _controller.value),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Head / Misc
// ─────────────────────────────────────────────────────────────────────────────

class _HomeHeader extends ConsumerWidget {
  final TrackingState tracking;
  final Color textDim;
  const _HomeHeader({required this.tracking, required this.textDim});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF002366), // Royal Blue
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              tracking.routeData?.college.toUpperCase() ?? 'VISCOUS TRACKER', 
              style: const TextStyle(
                color: Colors.white, 
                fontSize: 14, 
                fontWeight: FontWeight.w900, 
                letterSpacing: 1
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_active_rounded, color: Color(0xFFFFB930), size: 24),
          ),
          IconButton(
            onPressed: () {
              ref.read(currentTabProvider.notifier).state = 2; // Redirect to Profile
            },
            icon: const Icon(Icons.account_circle, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatefulWidget {
  final bool isLive;
  const _LiveBadge({required this.isLive});
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (!widget.isLive) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _kGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kGreen.withOpacity(0.4)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: _kGreen.withOpacity(0.7 + 0.3 * _controller.value))),
          const SizedBox(width: 5),
          const Text('LIVE', style: TextStyle(color: _kGreen, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
        ]),
      ),
    );
  }
}

class _PanelSegmentedBar extends StatelessWidget {
  final int value;
  final Color textDim;
  final ValueChanged<int> onChanged;
  const _PanelSegmentedBar({required this.value, required this.textDim, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme  = Theme.of(context);
    const labels = ['ETA', 'Admin', 'Map'];
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, 
        borderRadius: BorderRadius.circular(12), 
        border: Border.all(color: theme.dividerColor.withOpacity(0.1))
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: active ? _kCyan.withOpacity(0.18) : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(labels[i], 
                    style: TextStyle(
                      color: active ? _kCyan : textDim, 
                      fontSize: 12, 
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500
                    )),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PanelContent extends StatelessWidget {
  final int miniTab;
  final TrackingState tracking;
  final Color textDim;
  const _PanelContent({super.key, required this.miniTab, required this.tracking, required this.textDim});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (miniTab == 0) {
      return Row(children: [
        _StatChip(label: 'ETA', value: '${tracking.etaToNextMinutes} min', color: _kCyan),
        const SizedBox(width: 10),
        _StatChip(label: 'Delay', value: tracking.delayMinutes == 0 ? 'On time' : '${tracking.delayMinutes} min', color: tracking.delayMinutes == 0 ? _kGreen : _kAmber),
      ]);
    } else if (miniTab == 1) {
      return Row(children: [
        const Icon(Icons.admin_panel_settings_rounded, color: _kAmber, size: 16),
        const SizedBox(width: 8),
        Text('Status: ${tracking.routeData?.status ?? "Initializing..."}', style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 12)),
      ]);
    } else {
      return Row(children: [
        const Icon(Icons.map_rounded, color: _kCyan, size: 16),
        const SizedBox(width: 8),
        Text('Switching to live map...', style: TextStyle(color: textDim, fontSize: 12)),
      ]);
    }
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textDim = theme.brightness == Brightness.dark ? const Color(0xFF5A6A90) : const Color(0xFF64748B);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08), 
          borderRadius: BorderRadius.circular(10), 
          border: Border.all(color: color.withOpacity(0.2))
        ),
        child: Column(children: [
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label, style: TextStyle(color: textDim, fontSize: 10)),
        ]),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
        boxShadow: [
          if (theme.brightness == Brightness.light)
            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}
