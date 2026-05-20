import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isScanning = false;
  String _scanResult = "No item uploaded yet. Click below to choose an image!";
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickAndUploadImage() async {
    // Open the local system file/gallery dialog
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image == null) return; // User cancelled picking an image

    setState(() {
      _isScanning = true;
      _scanResult = "Uploading and processing image via Python API...";
    });

    // Make the real API network transaction
    final result = await ApiService.uploadAndScanImage(image);

    setState(() {
      _isScanning = false;
      if (result != null && result['status'] == 'success') {
        _scanResult =
            "✨ AI Detection Match:\n\n"
            "Item: ${result['detected_item']}\n"
            "Shelf Life Estimate: ${result['days_left']} Days\n"
            "File Logged: ${result['filename']}";
      } else {
        _scanResult =
            "❌ Error processing image. Check if Python server is online.";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '📸 Live AI Scanner',
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
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.green, width: 2),
              ),
              child: _isScanning
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    )
                  : const Icon(
                      Icons.cloud_upload_outlined,
                      size: 80,
                      color: Colors.green,
                    ),
            ),
            const SizedBox(height: 30),
            Card(
              color: Color(0xFF50C878),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _scanResult,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _pickAndUploadImage,
              icon: const Icon(Icons.photo_library),
              label: Text(
                _isScanning ? 'UPLOADING...' : 'CHOOSE IMAGE & ANALYZE',
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
