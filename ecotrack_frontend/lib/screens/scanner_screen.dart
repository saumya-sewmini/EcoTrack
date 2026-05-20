import 'package:flutter/material.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isScanning = false;
  String _scanResult = "No item scanned yet. Tap the button below!";

  // This function will simulate sending an image to our Python AI backend
  void _simulateAIScan() {
    setState(() {
      _isScanning = true;
    });

    // Simulate a 2-second network delay while Python "processes" the image
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _isScanning = false;
        _scanResult =
            "✨ AI Detection Result:\n\n🍉 Fresh Watermelon detected!\nEstimated Shelf Life: 7 Days";
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📸 Smart AI Scanner',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Simulated Camera View Finder / Box
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: _isScanning
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    )
                  : const Icon(Icons.camera_alt, size: 80, color: Colors.green),
            ),
            const SizedBox(height: 30),

            // AI Result Card
            Card(
              color: Color(0xFF50C878),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                key: ValueKey(_scanResult),
                child: Text(
                  _scanResult,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Scan Action Button
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _simulateAIScan,
              icon: const Icon(Icons.blur_on),
              label: Text(
                _isScanning ? 'AI ANALYZING...' : 'CAPTURE & ANALYZE',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
