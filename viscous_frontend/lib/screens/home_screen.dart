import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/storage_service.dart';
import '../models/login_response.dart';
import 'live_map_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  final bool isDarkMode;
  const HomeScreen({super.key, required this.onThemeChanged, required this.isDarkMode});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final StorageService _storageService = StorageService();

  LoginResponse? _userData;
  bool _isLoading = true;
  int _currentIndex = 0;

  static const Color royalBlue = Color(0xFF002366);
  static const Color mustardGold = Color(0xFFE1AD01);

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _storageService.getLoginData();
      if (mounted) {
        setState(() {
          _userData = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorAndNavigate('Session expired');
      }
    }
  }

  void _showErrorAndNavigate(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
    );
  }

  Future<void> _logout() async {
    setState(() => _isLoading = true);
    await _storageService.clearLoginData();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const LoginScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: royalBlue,
        body: Center(child: CircularProgressIndicator(color: mustardGold)),
      );
    }

    // Mapping for Bottom Nav (3 items now: Home, Map, Profile)
    // Home = 0, Map = 1, Profile = 2, Route = 3 (Hidden in nav)
    int navIndex = _currentIndex > 2 ? 1 : _currentIndex; 

    final List<Widget> views = [
      _HomeView(user: _userData?.user),
      const LiveMapScreen(),
      _ProfileView(
        user: _userData?.user, 
        onLogout: _logout, 
        isDarkMode: widget.isDarkMode, 
        onThemeChanged: widget.onThemeChanged
      ),
      const _RouteView(), // Route Schedule (Hidden in nav)
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E21) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? 'VISCOUS TRACKER' : (_currentIndex == 1 ? 'LIVE MAP' : (_currentIndex == 2 ? 'SETTINGS' : 'ROUTE SCHEDULE')),
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 16),
        ),
        backgroundColor: royalBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(icon: const Icon(Icons.notifications_active_outlined, color: mustardGold), onPressed: () {}),
          PopupMenuButton<int>(
            icon: const Icon(Icons.account_circle_rounded),
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            onSelected: (value) {
              setState(() => _currentIndex = value);
              if (value == 4) _logout();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0, child: Row(children: [Icon(Icons.dashboard_outlined, size: 20), SizedBox(width: 10), Text('Home Feed')])),
              const PopupMenuItem(value: 1, child: Row(children: [Icon(Icons.map_outlined, size: 20), SizedBox(width: 10), Text('Live Map')])),
              const PopupMenuItem(value: 3, child: Row(children: [Icon(Icons.alt_route, size: 20), SizedBox(width: 10), Text('Route Schedule')])),
              const PopupMenuItem(value: 2, child: Row(children: [Icon(Icons.person_outline, size: 20), SizedBox(width: 10), Text('My Profile')])),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 4, child: Row(children: [Icon(Icons.logout, size: 20, color: Colors.red), SizedBox(width: 10), Text('Logout', style: TextStyle(color: Colors.red))])),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: views,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navIndex,
        onTap: (index) {
           setState(() => _currentIndex = index);
        },
        backgroundColor: isDark ? const Color(0xFF1D1E33) : Colors.white,
        selectedItemColor: mustardGold,
        unselectedItemColor: isDark ? Colors.grey[600] : Colors.grey[400],
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on_rounded), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.account_circle), label: 'Profile'),
        ],
      ),
    );
  }
}

// --- VIEW: HOME TAB ---

class _HomeView extends StatefulWidget {
  final User? user;
  const _HomeView({this.user});

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const double headerHeight = 150.0;
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(top: headerHeight + 20, bottom: 80),
          child: Column(
            children: [
              _buildSearchHeader(isDark),
              const SizedBox(height: 30),
              _buildTimelineList(isDark),
            ],
          ),
        ),

        Positioned(
          top: 0, left: 0, right: 0,
          child: Container(
            height: headerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 25),
            decoration: const BoxDecoration(
              color: Color(0xFF002366),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(50), bottomRight: Radius.circular(50)),
              boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 15, offset: Offset(0, 5))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Welcome Back,', style: TextStyle(color: Colors.white70, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  widget.user?.name ?? 'Demo User',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Row(
                  children: [
                    Icon(Icons.directions_bus_rounded, color: Color(0xFFE1AD01), size: 16),
                    SizedBox(width: 8),
                    Text('V-Route: Downtown City Express', style: TextStyle(color: Color(0xFFE1AD01), fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchHeader(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!),
        boxShadow: !isDark ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)] : [],
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location_rounded, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 12),
          Text('Search Bus Stop...', style: TextStyle(color: isDark ? Colors.white38 : Colors.grey, fontSize: 15, fontWeight: FontWeight.w500)),
          const Spacer(),
          Icon(Icons.search, color: isDark ? Colors.white38 : Colors.grey),
        ],
      ),
    );
  }

  Widget _buildTimelineList(bool isDark) {
    final List<Map<String, dynamic>> stops = [
      {'name': 'Main Street', 'bus': '12', 'time': '5 min', 'side': 'left'},
      {'name': 'Central Plaza', 'bus': '7', 'time': '3 min', 'side': 'right'},
      {'name': 'Pine Station', 'bus': '21', 'time': 'Arriving', 'status': 'ACTIVE', 'side': 'left'},
      {'name': 'Elm Street', 'bus': '8', 'time': '12 min', 'side': 'right'},
      {'name': 'Riverfront', 'bus': '3', 'time': '18 min', 'side': 'left'},
      {'name': 'Oak Avenue', 'bus': '15', 'time': '25 min', 'side': 'right'},
    ];

    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: BusTimelinePainter(animation: _pulseController, isDark: isDark),
            ),
          ),
          Column(
            children: List.generate(stops.length, (index) {
              final stop = stops[index];
              final isLeft = stop['side'] == 'left';
              final isActive = stop['status'] == 'ACTIVE';

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: isLeft ? _buildStopCard(stop, isActive, isDark) : const SizedBox.shrink()),
                    const SizedBox(width: 80),
                    Expanded(child: !isLeft ? _buildStopCard(stop, isActive, isDark) : const SizedBox.shrink()),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStopCard(Map<String, dynamic> stop, bool isActive, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isActive 
                ? Colors.greenAccent.withOpacity(0.15) 
                : (isDark ? Colors.white.withOpacity(0.08) : Colors.white),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isActive ? Colors.greenAccent.withOpacity(0.5) : (isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: !isDark ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)] : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                   Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: isActive ? Colors.greenAccent : Colors.blueAccent)),
                   const SizedBox(width: 8),
                   Expanded(child: Text(stop['name'], style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13))),
                ],
              ),
              const SizedBox(height: 10),
              Text('Bus ${stop['bus']} - ${stop['time']}', style: TextStyle(color: isActive ? (isDark ? Colors.greenAccent : Colors.green[700]) : (isDark ? Colors.white70 : Colors.black54), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class BusTimelinePainter extends CustomPainter {
  final Animation<double> animation;
  final bool isDark;
  BusTimelinePainter({required this.animation, required this.isDark}) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width == 0) return;
    final centerX = size.width / 2;
    final roadColor = isDark ? Colors.white.withOpacity(0.08) : Colors.grey[300]!;
    final roadPaint = Paint()..color = roadColor..strokeWidth = 14..style = PaintingStyle.stroke;
    final dashPaint = Paint()..color = isDark ? Colors.white.withOpacity(0.4) : Colors.grey[400]!..strokeWidth = 2..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), roadPaint);
    double currentY = 0;
    while (currentY < size.height) {
      canvas.drawLine(Offset(centerX, currentY), Offset(centerX, currentY + 12), dashPaint);
      currentY += 24;
    }

    final double yBetween = 85.0 + (1.6 * 125.0); 
    final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(Icons.directions_bus.codePoint),
      style: TextStyle(
        fontSize: 38, 
        fontFamily: Icons.directions_bus.fontFamily,
        color: Colors.greenAccent,
        shadows: [Shadow(color: Colors.greenAccent.withOpacity(0.8), blurRadius: 20 * animation.value)],
      ),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(centerX - 19, yBetween - 19));

    final dotPaint = Paint()..style = PaintingStyle.fill;
    final glowPaint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    for (int i = 0; i < 6; i++) {
        final yPos = 85.0 + (i * 125.0);
        final color = (i == 2) ? Colors.greenAccent : Colors.blueAccent;
        glowPaint.color = color.withOpacity(0.4 * animation.value);
        canvas.drawCircle(Offset(centerX, yPos), 12, glowPaint);
        dotPaint.color = color;
        canvas.drawCircle(Offset(centerX, yPos), 6, dotPaint);
        final linePaint = Paint()..color = color.withOpacity(0.4)..strokeWidth = 1.5;
        final isLeft = i % 2 == 0;
        canvas.drawLine(Offset(centerX, yPos), Offset(isLeft ? centerX - 35 : centerX + 35, yPos), linePaint);
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- VIEW: ROUTE TAB (The BORDERLESS TABLE / CHART) ---

class _RouteView extends StatelessWidget {
  const _RouteView();

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Map<String, dynamic>> routeData = [
      {'stop': 'Main Street Station', 'reach': '08:15 AM', 'status': 'PASSED', 'color': Colors.grey},
      {'stop': 'Central Plaza Hub', 'reach': '08:22 AM', 'status': 'PASSED', 'color': Colors.grey},
      {'stop': 'Pine Station (Main)', 'reach': '08:35 AM', 'status': 'ARRIVED', 'color': Colors.greenAccent},
      {'stop': 'Elm Street North', 'reach': '08:42 AM', 'status': '5 MIN', 'color': Colors.blueAccent},
      {'stop': 'Lakeside Stop', 'reach': '08:55 AM', 'status': '12 MIN', 'color': Colors.blueAccent},
      {'stop': 'Riverfront Crossing', 'reach': '09:05 AM', 'status': '22 MIN', 'color': Colors.white38},
      {'stop': 'Oak Avenue Square', 'reach': '09:15 AM', 'status': '32 MIN', 'color': Colors.white38},
      {'stop': 'Final Terminal', 'reach': '10:00 AM', 'status': '1.5 HR', 'color': Colors.white10},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LIVE ROUTE SCHEDULE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 14, color: Color(0xFFE1AD01))),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white, borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), topRight: Radius.circular(15)), border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!))),
            child: Row(children: [Expanded(flex: 3, child: Text('BUS STOP', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey))), Expanded(flex: 2, child: Text('EST. REACH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey))), Expanded(flex: 2, child: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey)))]),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: routeData.length,
              itemBuilder: (context, index) {
                final data = routeData[index];
                bool isCurrent = data['status'] == 'ARRIVED';
                bool isPassed = data['status'] == 'PASSED';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                  decoration: BoxDecoration(color: isCurrent ? Colors.greenAccent.withOpacity(0.1) : Colors.transparent, border: Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.03) : Colors.grey[50]!))),
                  child: Row(children: [Expanded(flex: 3, child: Row(children: [Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: data['color'])), const SizedBox(width: 10), Expanded(child: Text(data['stop'], style: TextStyle(fontSize: 13, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal, color: isPassed ? Colors.grey : (isDark ? Colors.white : Colors.black87))))])), Expanded(flex: 2, child: Text(data['reach'], style: TextStyle(fontSize: 12, color: isPassed ? Colors.grey : (isDark ? Colors.white70 : Colors.black54), fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal))), Expanded(flex: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: data['color'].withOpacity(0.1), borderRadius: BorderRadius.circular(5)), child: Text(data['status'], textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: data['color']))))]),
                );
              },
            ),
          ),
          Container(height: 10, width: double.infinity, decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.02) : Colors.transparent, borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)))),
        ],
      ),
    );
  }
}

// --- VIEW: PROFILE PAGE ---

class _ProfileView extends StatelessWidget {
  final User? user;
  final VoidCallback onLogout;
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  const _ProfileView({this.user, required this.onLogout, required this.isDarkMode, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircleAvatar(radius: 50, backgroundColor: Color(0xFF002366), child: Icon(Icons.person, size: 60, color: Colors.white)),
          const SizedBox(height: 16),
          Text(user?.name ?? 'User Name', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 32),
          _buildItem(context, Icons.person, 'Name', user?.name ?? 'N/A'),
          _buildItem(context, Icons.phone, 'Phone', user?.phone ?? 'N/A'),
          _buildItem(context, Icons.email, 'Email', user?.email ?? 'N/A'),
          _buildItem(context, Icons.school, 'College', user?.college ?? 'N/A'),
          _buildItem(context, Icons.route, 'Route', user?.route ?? 'N/A'),
          _buildItem(context, Icons.badge, 'Role', user?.role ?? 'N/A'),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[200]!), boxShadow: !isDark ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)] : []),
            child: SwitchListTile(title: const Text('DARK MODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)), subtitle: const Text('Toggle between dark and light themes', style: TextStyle(fontSize: 11)), secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: const Color(0xFFE1AD01)), activeColor: const Color(0xFFE1AD01), value: isDarkMode, onChanged: onThemeChanged),
          ),
          const SizedBox(height: 40),
          SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout), label: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), elevation: 0))),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, IconData icon, String label, String value) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(leading: Icon(icon, color: const Color(0xFFE1AD01)), title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), subtitle: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)));
  }
}