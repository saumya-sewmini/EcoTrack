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

  /// Synchronizes the local presentation state with the remote data repository stream.
  void _refreshPantry() {
    setState(() {
      _pantryFuture = ApiService.fetchPantryItems();
    });
  }

  /// Displays the interactive recipe intelligence sheet.
  /// The collection future is evaluated outside the builder to guarantee lifecycle stability.
  void _showAIChefDialog() {
    final Future<String> recipeInferenceFuture = ApiService.fetchAIChefRecipe();

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
          height: MediaQuery.of(context).size.height * 0.75,
          child: FutureBuilder<String>(
            future: recipeInferenceFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          CustomColors.amberDetail,
                        ),
                        strokeWidth: 2.5,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Orchestrating menu variants from active inventory...",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF5F6368),
                        ),
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
                        "AI Generative Recipes",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: CustomColors.amberDetail,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: Color(0xFF5F6368),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFF1F3F4)),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        snapshot.data ??
                            "Inference cycle returned no valid processing guidelines.",
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: Color(0xFF202124),
                        ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Inventory Ledger',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              Icons.refresh_rounded,
              color: theme.colorScheme.secondary,
            ),
            onPressed: _refreshPantry,
          ),
        ],
      ),
      body: FutureBuilder<List<dynamic>?>(
        future: _pantryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
                strokeWidth: 2.5,
              ),
            );
          } else if (snapshot.hasError || snapshot.data == null) {
            return const Center(
              child: Text(
                'Data Synchronizer Error: Pipeline execution failed.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          final items = snapshot.data!;

          if (items.isEmpty) {
            return Center(
              child: Text(
                'Tracking database is empty. Scan assets to populate registry.',
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 8.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummaryDashboard(items),
                _buildExpiryAlertBanner(items),
                const SizedBox(height: 16),
                const Text(
                  "REGISTERED TRACKING POOL",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Color(0xFF5F6368),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final isUrgent = (item['days_left'] ?? 0) <= 1;

                      return Dismissible(
                        key: Key(item['id'].toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.delete_sweep_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        onDismissed: (direction) async {
                          final success = await ApiService.deletePantryItem(
                            item['id'],
                          );
                          if (success) {
                            setState(() {
                              items.removeAt(index);
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Safely removed asset reference: ${item['name']}',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            _refreshPantry();
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isUrgent
                                  ? Colors.red.shade200
                                  : const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: isUrgent
                                  ? Colors.red.shade50
                                  : const Color(0xFFF1F3F4),
                              child: Icon(
                                isUrgent
                                    ? Icons.error_outline_rounded
                                    : Icons.inventory_2_outlined,
                                color: isUrgent
                                    ? Colors.red.shade700
                                    : const Color(0xFF5F6368),
                                size: 20,
                              ),
                            ),
                            title: Text(
                              item['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF202124),
                              ),
                            ),
                            subtitle: Text(
                              'Quantity Metric: ${item['quantity']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF5F6368),
                              ),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isUrgent
                                    ? Colors.red.shade50
                                    : const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${item['days_left']} Days Left',
                                style: TextStyle(
                                  color: isUrgent
                                      ? Colors.red.shade800
                                      : CustomColors.amberDetail,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
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
        backgroundColor: CustomColors.amberDetail,
        elevation: 2,
        icon: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
        label: const Text(
          "INITIALIZE AI KITCHEN CHEF",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryDashboard(List<dynamic> items) {
    final totalCount = items.length;
    final urgentCount = items
        .where((item) => (item['days_left'] ?? 0) <= 1)
        .length;
    final stableCount = totalCount - urgentCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          _buildStatCard(
            "Total Pools",
            totalCount.toString(),
            const Color(0xFFE8F0FE),
            const Color(0xFF1967D2),
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            "Critical Action",
            urgentCount.toString(),
            const Color(0xFFFCE8E6),
            const Color(0xFFC5221F),
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            "Nominal Items",
            stableCount.toString(),
            const Color(0xFFE6F4EA),
            const Color(0xFF137333),
          ),
        ],
      ),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpiryAlertBanner(List<dynamic> items) {
    final criticalItems = items
        .where((item) => (item['days_left'] ?? 0) <= 1)
        .toList();

    if (criticalItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE8E6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFAD2CF), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.report_problem_rounded,
                color: Color(0xFFC5221F),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                "CRITICAL EXPIRY TELEMETRY ALERTS (${criticalItems.length})",
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC5221F),
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...criticalItems.map((item) {
            final isExpired = (item['days_left'] ?? 0) == 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.arrow_right_rounded,
                    color: Color(0xFFC5221F),
                    size: 16,
                  ),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Color(0xFF202124),
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: item['name'],
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: isExpired
                                ? " has crossed retention duration limit."
                                : " approaches immediate exhaustion window.",
                            style: const TextStyle(
                              color: Color(0xFFC5221F),
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
}

class CustomColors {
  static const Color amberDetail = Color(0xFFD97706);
}
