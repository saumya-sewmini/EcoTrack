import 'package:flutter/material.dart';
import 'screens/pantry_screen.dart';
import 'screens/scanner_screen.dart';
import 'services/api_service.dart';

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
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50), // Premium Emerald green base
          primary: const Color(0xFF0F9D58),
          secondary: const Color(0xFF202124),
          surface: Colors.white,
          // ignore: deprecated_member_use
          background: const Color(0xFFF8F9FA), // Clean, soft neutral background
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
          ),
        ),
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

  /// Synchronizes local state with backend inventory database.
  void _refreshDashboard() {
    setState(() {
      _dashboardDataFuture = ApiService.fetchPantryItems();
    });
  }

  /// Evaluates current inventory urgency and returns a contextual warning component
  /// if any tracked assets fall below the critical threshold (<= 2 days).
  Widget _buildDynamicAlertCard(List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    // Sort items by ascending shelf life to isolate the most critical asset
    final List<dynamic> sortedItems = List.from(items);
    sortedItems.sort(
      (a, b) => (a['days_left'] ?? 0).compareTo(b['days_left'] ?? 0),
    );

    final mostUrgentItem = sortedItems.first;
    final int days = mostUrgentItem['days_left'] ?? 0;

    // Suppress warning display if the closest expiry date exceeds target window
    if (days > 2) return const SizedBox.shrink();

    final String warningMessage = days == 0
        ? "Urgent: ${mostUrgentItem['name']} has expired."
        : "Attention: ${mostUrgentItem['name']} expires in $days day${days > 1 ? 's' : ''}.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFC1C1), width: 1),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFD93025),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              warningMessage,
              style: const TextStyle(
                color: Color(0xFFC5221F),
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'EcoTrack Hub',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            letterSpacing: -0.4,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshDashboard,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>?>(
        future: _dashboardDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2.5),
            );
          }

          final liveItems = snapshot.data ?? [];

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Optimize household consumption and mitigate waste.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),

                  _buildDynamicAlertCard(liveItems),

                  const SizedBox(height: 28),
                  const Text(
                    'RECENT QUEUE',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Color(0xFF5F6368),
                    ),
                  ),
                  const SizedBox(height: 12),

                  if (liveItems.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Center(
                        child: Text(
                          'No items currently tracked. Scan an item to populate data.',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    // Isolate the top three most recently added dataset mutations
                    ...liveItems.reversed.take(3).map((item) {
                      final int daysLeft = item['days_left'] ?? 0;
                      final bool isUrgent = daysLeft <= 1;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Card(
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: isUrgent
                                  ? const Color(0xFFFCE8E6)
                                  : const Color(0xFFE6F4EA),
                              radius: 18,
                              child: Icon(
                                isUrgent
                                    ? Icons.priority_high_rounded
                                    : Icons.restaurant_menu_rounded,
                                color: isUrgent
                                    ? const Color(0xFFC5221F)
                                    : const Color(0xFF137333),
                                size: 16,
                              ),
                            ),
                            title: Text(
                              item['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              item['quantity'],
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isUrgent
                                    ? const Color(0xFFFCE8E6)
                                    : const Color(0xFFF1F3F4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${daysLeft}d remaining',
                                style: TextStyle(
                                  color: isUrgent
                                      ? const Color(0xFFC5221F)
                                      : const Color(0xFF3C4043),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                  const SizedBox(height: 24),

                  // Unified high-contrast primary actions interface row
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ScannerScreen(),
                              ),
                            );
                            _refreshDashboard();
                          },
                          icon: const Icon(Icons.camera_alt_rounded, size: 18),
                          label: const Text('SCAN ITEM'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PantryScreen(),
                              ),
                            );
                            _refreshDashboard();
                          },
                          icon: const Icon(Icons.grid_view_rounded, size: 18),
                          label: const Text('VIEW PANTRY'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: theme.colorScheme.secondary,
                            side: const BorderSide(
                              color: Color(0xFFDADCE0),
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.5,
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
