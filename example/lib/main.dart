import 'package:flutter/material.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:advanced_image_processing_toolkit/src/filters.dart';
import 'package:advanced_image_processing_toolkit/src/object_recognition.dart';
import 'package:image/image.dart' as img;
import 'dart:io' show File;
import 'feature_test.dart';

final _logger = Logger('AdvancedImageProcessingToolkit');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configure logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });
  
  // Request permissions
  if (!await Permission.camera.isGranted) {
    await Permission.camera.request();
  }
  if (!await Permission.storage.isGranted) {
    await Permission.storage.request();
  }
  
  // Initialize the toolkit
  await AdvancedImageProcessingToolkit.initialize(
    enableObjectDetection: true,
    enableAR: false, // Set to true if AR dependencies are added
  );
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Advanced Image Processing Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Image Processing Toolkit'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Advanced Image Processing Toolkit',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Version: ${AdvancedImageProcessingToolkit.version}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Capabilities:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildFeatureList(),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FeatureTest()),
                );
              },
              icon: const Icon(Icons.science),
              label: const Text('Run Feature Test Suite'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFeatureList() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _FeatureItem(
            icon: Icons.filter,
            label: 'Real-time image filters',
          ),
          SizedBox(height: 8),
          _FeatureItem(
            icon: Icons.palette,
            label: 'Artistic effects',
          ),
          SizedBox(height: 8),
          _FeatureItem(
            icon: Icons.search,
            label: 'Object detection & recognition',
          ),
          SizedBox(height: 8),
          _FeatureItem(
            icon: Icons.face,
            label: 'Face detection & analysis',
          ),
          SizedBox(height: 8),
          _FeatureItem(
            icon: Icons.text_fields,
            label: 'Text recognition (OCR)',
          ),
          SizedBox(height: 8),
          _FeatureItem(
            icon: Icons.sports_gymnastics,
            label: 'Pose estimation',
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[800],
            ),
          ),
        ),
      ],
    );
  }
}
