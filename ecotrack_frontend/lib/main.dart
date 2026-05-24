import 'package:flutter/material.dart';
import 'screens/pantry_screen.dart';
import 'screens/scanner_screen.dart';
import 'services/api_service.dart'; // 🔌 Crucial import link to fetch live items

void main() {
  runApp(const EcoTrackApp());
}

class EcoTrackApp extends StatelessWidget {
  const EcoTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EcoTrack AI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color.fromARGB(255, 0, 255, 128),
          // ignore: deprecated_member_use
          background: Colors.grey.shade50,
        ),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<dynamic>?> _dashboardDataFuture;

  @override
  void initState() {
    super.initState();
    _refreshDashboard();
  }

  // Reload action handler to pull the latest backend SQLite data array state
  void _refreshDashboard() {
    setState(() {
      _dashboardDataFuture = ApiService.fetchPantryItems();
    });
  }

  // 🚨 DYNAMIC RISK ENGINE: Scans database array to find the single most critical item
  Widget _buildDynamicAlertCard(List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Sort items so the lowest days_left sits right at the top index position
    List<dynamic> sortedItems = List.from(items);
    sortedItems.sort(
      (a, b) => (a['days_left'] ?? 0).compareTo(b['days_left'] ?? 0),
    );

    final mostUrgentItem = sortedItems.first;
    final int days = mostUrgentItem['days_left'] ?? 0;

    // If even our closest item is safe and stable, don't alarm the user
    if (days > 2) return const SizedBox.shrink();

    String warningMessage = days == 0
        ? "🚨 Urgent: ${mostUrgentItem['name']} has expired completely!"
        : "⏳ Attention: ${mostUrgentItem['name']} expires in $days day${days > 1 ? 's' : ''}!";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.pink.shade50,
            Colors.red.shade50.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade200.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt, color: Colors.red.shade800, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              warningMessage,
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'EcoTrack Hub',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.grey.shade900,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.cached_rounded, color: Colors.grey.shade800),
            onPressed: _refreshDashboard, // Pull latest storage snapshot on tap
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>?>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color.fromARGB(255, 0, 255, 128),
                strokeWidth: 3,
              ),
            );
          }

          final liveItems = snapshot.data ?? [];

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome Header Row
                  Text(
                    'Welcome Back! 👋',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Let\'s optimize your kitchen consumption.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  // 1. Dynamic Alert Banner Section
                  _buildDynamicAlertCard(liveItems),

                  const SizedBox(height: 32),

                  // Recent Items Headline Section
                  Text(
                    'RECENT KITCHEN ACQUISITIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.grey.shade500,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Dynamic Database Content Builder
                  if (liveItems.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '🥗 No active tracking items detected. Scan to begin!',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    // Take up to the top 3 most recently loaded items out of SQLite
                    ...liveItems.reversed.take(3).map((item) {
                      final int daysLeft = item['days_left'] ?? 0;
                      final bool isUrgent = daysLeft <= 1;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.01),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isUrgent
                                  ? Colors.orange.shade50
                                  : Color.fromARGB(255, 0, 255, 128),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isUrgent
                                  ? Icons.error_outline_rounded
                                  : Icons.bakery_dining_outlined,
                              color: isUrgent
                                  ? Colors.orange.shade800
                                  : Colors.green.shade700,
                              size: 18,
                            ),
                          ),
                          title: Text(
                            item['name'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            item['quantity'],
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isUrgent
                                  ? Colors.red.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${daysLeft}d left',
                              style: TextStyle(
                                color: isUrgent
                                    ? Colors.red.shade900
                                    : Colors.grey.shade700,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 36),

                  // 3. High-Contrast Premium Action Interface Triggers
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ScannerScreen(),
                              ),
                            );
                            _refreshDashboard(); // Sync up layout views instantly upon camera pop exit action
                          },
                          icon: const Icon(
                            Icons.center_focus_strong_rounded,
                            size: 20,
                          ),
                          label: const Text(
                            'LAUNCH VISION SCANNER',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              0,
                              255,
                              128,
                            ),
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: Color.fromARGB(
                              255,
                              0,
                              255,
                              128,
                            ).withValues(alpha: 0.2),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PantryScreen(),
                              ),
                            );
                            _refreshDashboard(); // Resync summary items when coming back
                          },
                          icon: Icon(
                            Icons.grid_view_rounded,
                            color: const Color.fromARGB(255, 0, 255, 128),
                            size: 20,
                          ),
                          label: Text(
                            'MANAGE DIGITAL PANTRY',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color.fromARGB(255, 0, 255, 128),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: const Color.fromARGB(
                                255,
                                0,
                                255,
                                128,
                              ).withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
