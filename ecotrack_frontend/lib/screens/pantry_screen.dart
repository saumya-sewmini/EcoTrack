import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  late Future<List<dynamic>?> _pantryFuture;

  @override
  void initState() {
    super.initState();
    _refreshPantry();
  }

  void _refreshPantry() {
    setState(() {
      _pantryFuture = ApiService.fetchPantryItems();
    });
  }

  void _showAIChefDialog() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.7,
          child: FutureBuilder<String>(
            future: ApiService.fetchAIChefRecipe(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.amber),
                      SizedBox(height: 16),
                      Text(
                        "🍳 EcoChef is combining your ingredients...",
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "✨ AI Recipe Suggestions",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CustomColors.amberDetail,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        snapshot.data ?? "No recipe found.",
                        style: const TextStyle(fontSize: 15, height: 1.5),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // Summary Metrics Dashboard Component
  Widget _buildSummaryDashboard(List<dynamic> items) {
    final totalCount = items.length;
    final urgentCount = items
        .where((item) => (item['days_left'] ?? 0) <= 1)
        .length;
    final stableCount = totalCount - urgentCount;

    return Row(
      children: [
        _buildStatCard(
          "Total Items",
          totalCount.toString(),
          Colors.blue.shade100,
          Colors.blue.shade900,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          "Use Urgent",
          urgentCount.toString(),
          Colors.red.shade100,
          Colors.red.shade900,
        ),
        const SizedBox(width: 12),
        _buildStatCard(
          "Stable",
          stableCount.toString(),
          Colors.green.shade100,
          Colors.green.shade900,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color bgColor,
    Color textColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⚠️ NEW: Intelligent Expiry Alert Banner Widget
  Widget _buildExpiryAlertBanner(List<dynamic> items) {
    // Filter out items that are expiring today (0 days) or tomorrow (1 day)
    final criticalItems = items
        .where((item) => (item['days_left'] ?? 0) <= 1)
        .toList();

    // If everything is completely safe, collapse the widget to prevent empty screen padding
    if (criticalItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                "CRITICAL EXPIRY ALERTS (${criticalItems.length})",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Loop and generate inline micro-warnings for high risk items
          ...criticalItems.map((item) {
            final isExpired = (item['days_left'] ?? 0) == 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Icon(Icons.arrow_right, color: Colors.red.shade400, size: 18),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: item['name'],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: isExpired
                                ? " has EXPIRED! 🚨"
                                : " expires TOMORROW! ⏳",
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📋 Current Digital Pantry',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade100,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshPantry,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>?>(
        future: _pantryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          } else if (snapshot.hasError || snapshot.data == null) {
            return const Center(child: Text('❌ Could not load pantry items.'));
          }

          final items = snapshot.data!;

          if (items.isEmpty) {
            return const Center(
              child: Text(
                '🥗 Your pantry is sparkling clean! Scan food to begin tracking.',
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildSummaryDashboard(items),

                // 🚨 Injecting our new reactive Expiry Warning engine
                _buildExpiryAlertBanner(items),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "All Inventory Items",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isUrgent = (item['days_left'] ?? 0) <= 1;

                      return Dismissible(
                        key: Key(item['id'].toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (direction) async {
                          final success = await ApiService.deletePantryItem(
                            item['id'],
                          );
                          if (success) {
                            setState(() {
                              items.removeAt(index);
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Removed ${item['name']}'),
                                ),
                              );
                            }
                          } else {
                            _refreshPantry();
                          }
                        },
                        child: Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          // Highlight the physical card border if it is urgent
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isUrgent
                                ? BorderSide(
                                    color: Colors.red.shade300,
                                    width: 1,
                                  )
                                : BorderSide.none,
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isUrgent
                                  ? Colors.red.shade100
                                  : Colors.greenAccent,
                              child: Icon(
                                isUrgent
                                    ? Icons.priority_high
                                    : Icons.restaurant,
                                color: isUrgent
                                    ? Colors.red.shade900
                                    : Colors.green.shade900,
                              ),
                            ),
                            title: Text(
                              item['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text('Quantity: ${item['quantity']}'),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isUrgent
                                    ? Colors.red.shade100
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${item['days_left']} days left',
                                style: TextStyle(
                                  color: isUrgent
                                      ? Colors.red.shade900
                                      : Colors.orange.shade900,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAIChefDialog,
        backgroundColor: Colors.amber,
        icon: const Icon(Icons.auto_awesome, color: Colors.black87),
        label: const Text(
          "ASK AI CHEF",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class CustomColors {
  static const Color amberDetail = Color(0xFFD97706);
}
