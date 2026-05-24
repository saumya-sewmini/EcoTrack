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

  // Helper method to reload data smoothly from the server
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
                          color: Color(0xFFD4AF37),
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

  // 📊 NEW: A modular row widget that calculates and displays kitchen statistics
  Widget _buildSummaryDashboard(List<dynamic> items) {
    final totalCount = items.length;

    // Count items with 1 day or less remaining
    final urgentCount = items
        .where((item) => (item['days_left'] ?? 0) <= 1)
        .length;
    final stableCount = totalCount - urgentCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
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
      ),
    );
  }

  // Helper widget to construct individual metric boxes cleanly
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
                color: textColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
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
            onPressed:
                _refreshPantry, // Quick manual sync action refresh button
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
                // 1. Injection of our dynamic metrics banner
                _buildSummaryDashboard(items),

                // 2. Wrapped listview inside an Expanded component to share layout space safely
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
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
                            // Remove locally straight away to keep rendering fast and snapping smooth
                            setState(() {
                              items.removeAt(index);
                            });
                            if (mounted) {
                              // ignore: use_build_context_synchronously
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Removed ${item['name']}'),
                                ),
                              );
                            }
                          } else {
                            // Rollback if server fails connection
                            _refreshPantry();
                          }
                        },
                        child: Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.greenAccent,
                              child: Icon(
                                Icons.restaurant,
                                color: Color(0xFF006400),
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
                                color: (item['days_left'] ?? 0) <= 1
                                    ? Colors.red.shade100
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${item['days_left']} days left',
                                style: TextStyle(
                                  color: (item['days_left'] ?? 0) <= 1
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

extension CustomColors on TextStyle {
  static const Color amberDetail = Color(0xFFD97706);
}
