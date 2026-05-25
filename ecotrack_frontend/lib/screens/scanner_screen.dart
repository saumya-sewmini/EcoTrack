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
  String? _detectedItem;
  int? _daysLeft;
  String _statusMessage =
      "Select an image from the system gallery to initialize computer vision analysis.";
  final ImagePicker _picker = ImagePicker();

  /// Invokes the native platform image selection interface and orchestrates
  /// the asynchronous network lifecycle for handling asset inference via the backend.
  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image == null)
      return; // Operational escape hatch if selection is cancelled

    setState(() {
      _isScanning = true;
      _statusMessage =
          "Transmitting image binary stream to computer vision inference model...";
      _detectedItem = null;
      _daysLeft = null;
    });

    try {
      // Execute multipart network transaction via the API layer
      final result = await ApiService.uploadAndScanImage(image);

      setState(() {
        _isScanning = false;
        if (result != null && result['status'] == 'success') {
          _detectedItem = result['detected_item'] ?? 'Unknown Asset';
          _daysLeft = result['days_left'] ?? 0;
          _statusMessage =
              "Inference processing complete. Asset safely registered to tracking pipeline.";
        } else {
          _statusMessage =
              "Inference exception: Malformed response payload received from server.";
        }
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _statusMessage =
            "Network transaction failure. Ensure backend services are running.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // ignore: deprecated_member_use
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text(
          'Vision Analytics',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.colorScheme.secondary,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Visualization Drop Zone Viewport
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isScanning
                        ? theme.colorScheme.primary
                        : const Color(0xFFE0E0E0),
                    width: 1.5,
                  ),
                ),
                child: _isScanning
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                              strokeWidth: 2.5,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Processing Texture Arrays...',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.center_focus_strong_rounded,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Awaiting Image Content Payload',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Metadata Logging Console Box
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'INFERENCE CONSOLE OUTPUT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: Color(0xFF5F6368),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_detectedItem != null) ...[
                      _buildTelemetryRow('Identified Object', _detectedItem!),
                      const Divider(height: 20, color: Color(0xFFF1F3F4)),
                      _buildTelemetryRow(
                        'Calculated Shelf Life',
                        '$_daysLeft Days',
                      ),
                      const Divider(height: 20, color: Color(0xFFF1F3F4)),
                    ],
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 13,
                        color: _detectedItem != null
                            ? Colors.grey.shade600
                            : theme.colorScheme.secondary,
                        fontWeight: _detectedItem != null
                            ? FontWeight.normal
                            : FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Execution Trigger Control
            ElevatedButton.icon(
              onPressed: _isScanning ? null : _pickAndUploadImage,
              icon: const Icon(Icons.photo_library_rounded, size: 18),
              label: Text(
                _isScanning
                    ? 'UPLOADING DATASET...'
                    : 'SELECT GALLERY RAW IMAGE',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade100,
                disabledForegroundColor: Colors.grey.shade400,
                padding: const EdgeInsets.symmetric(vertical: 18),
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
          ],
        ),
      ),
    );
  }

  /// Helper layout builder generating structured key-value tracking pairs.
  Widget _buildTelemetryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5F6368),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF202124),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
