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

final _logger = Logger('AdvancedImageProcessingToolkit');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Only request permissions on mobile platforms
  if (!kIsWeb) {
    await Permission.photos.request();
    await Permission.storage.request();
  }
  
  // Initialize logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });
  
  // Initialize the toolkit
  await AdvancedImageProcessingToolkit.initialize(
    enableObjectDetection: true,
    enableAR: false, // Disable AR for now to avoid dependency issues
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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Uint8List? _imageBytes;
  Uint8List? _processedImageBytes; // Use Uint8List for web compatibility
  final _picker = ImagePicker();
  List<DetectedObject>? _detectedObjects;
  bool _isProcessing = false;
  String _processingMethod = '';

  @override
  void initState() {
    super.initState();
    // Load sample image on startup
    _loadSampleImage();
  }

  Future<void> _loadSampleImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/sample_image.jpg');
      final bytes = data.buffer.asUint8List();
      setState(() {
        _imageBytes = bytes;
        _processedImageBytes = null;
        _detectedObjects = null;
      });
    } catch (e) {
      _logger.warning('Failed to load sample image: $e');
      _showError('Failed to load sample image: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _processedImageBytes = null;
          _detectedObjects = null;
        });
      }
    } catch (e) {
      _logger.warning('Failed to pick image: $e');
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _takePhoto() async {
    // Request camera permission only when needed and not on web
    if (!kIsWeb) {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
        if (!status.isGranted) {
          _showError('Camera permission is required to take a photo');
          return;
        }
      }
    }
    
    try {
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _processedImageBytes = null;
          _detectedObjects = null;
        });
      }
    } catch (e) {
      _logger.warning('Failed to take photo: $e');
      _showError('Failed to take photo: $e');
    }
  }

  Future<void> _processImage(String method) async {
    if (_imageBytes == null) return;

    setState(() {
      _isProcessing = true;
      _processingMethod = method;
    });

    try {
      Uint8List processedBytes;
      
      switch (method) {
        case 'grayscale':
          processedBytes = await ImageFilters.applyGrayscale(_imageBytes!);
          break;
        case 'blur':
          processedBytes = await ImageFilters.applyBlur(_imageBytes!, 5.0);
          break;
        case 'brightness_increase':
          processedBytes = await ImageFilters.adjustBrightness(_imageBytes!, 0.5);
          break;
        case 'brightness_decrease':
          processedBytes = await ImageFilters.adjustBrightness(_imageBytes!, -0.5);
          break;
        case 'sepia':
          processedBytes = await ImageFilters.applySepia(_imageBytes!);
          break;
        case 'invert':
          processedBytes = await ImageFilters.applyInvert(_imageBytes!);
          break;
        case 'vignette':
          processedBytes = await ImageFilters.applyVignette(
            _imageBytes!,
            intensity: 0.5,
            radius: 0.5,
          );
          break;
        case 'watercolor':
          processedBytes = await ImageFilters.applyWatercolor(
            _imageBytes!,
            radius: 5,
            intensity: 0.5,
          );
          break;
        case 'oil_painting':
          processedBytes = await ImageFilters.applyOilPainting(
            _imageBytes!,
            radius: 4,
            levels: 20,
          );
          break;
        case 'object_detection':
          try {
            final detections = await ObjectRecognition.detectObjects(_imageBytes!);
            setState(() {
              _detectedObjects = detections;
            });
            _logger.info('Detected ${detections.length} objects');
            
            // Draw bounding boxes
            processedBytes = await ObjectRecognition.drawDetections(
              _imageBytes!,
              detections,
            );
          } catch (e) {
            _logger.warning('Failed to detect objects: $e');
            processedBytes = _imageBytes!;
          }
          break;
        default:
          processedBytes = _imageBytes!;
      }
      
      // Save the processed image (as bytes for web compatibility)
      if (!kIsWeb) {
        try {
          final tempDir = await getTemporaryDirectory();
          final outputPath = '${tempDir.path}/processed_image.jpg';
          await File(outputPath).writeAsBytes(processedBytes);
        } catch (e) {
          _logger.warning('Failed to save processed image to file: $e');
        }
      }
      
      // Update UI with processed image
      setState(() {
        _processedImageBytes = processedBytes;
        _isProcessing = false;
      });
      
      // Log success
      _logger.info('Successfully processed image with $method');
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _logger.warning('Failed to process image: $e');
      _showError('Failed to process image: $e');
    }
  }
  
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Image Processing Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSampleImage,
            tooltip: 'Load Sample Image',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  if (_imageBytes != null) ...[
                    Image.memory(
                      _processedImageBytes ?? _imageBytes!,
                      fit: BoxFit.contain,
                    ),
                    if (_detectedObjects != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Detected Objects:',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      ..._detectedObjects!.map((obj) => ListTile(
                        title: Text(obj.label),
                        subtitle: Text(
                          'Confidence: ${(obj.confidence * 100).toStringAsFixed(1)}%',
                        ),
                        trailing: obj.additionalData != null
                            ? IconButton(
                                icon: const Icon(Icons.info),
                                onPressed: () => _showObjectDetails(obj),
                              )
                            : null,
                      )),
                    ],
                  ],
                ],
              ),
            ),
          ),
          if (_isProcessing)
            const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Pick Image'),
                  onPressed: _pickImage,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                  onPressed: _takePhoto,
                ),
                const SizedBox(width: 16),
                _buildFilterButton('Grayscale', 'grayscale'),
                _buildFilterButton('Blur', 'blur'),
                _buildFilterButton('Brightness +', 'brightness_increase'),
                _buildFilterButton('Brightness -', 'brightness_decrease'),
                _buildFilterButton('Sepia', 'sepia'),
                _buildFilterButton('Invert', 'invert'),
                _buildFilterButton('Vignette', 'vignette'),
                _buildFilterButton('Watercolor', 'watercolor'),
                _buildFilterButton('Oil Painting', 'oil_painting'),
                _buildFilterButton('Detect Objects', 'object_detection'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String label, String method) {
    return ElevatedButton(
      onPressed: _isProcessing ? null : () => _processImage(method),
      child: Text(label),
    );
  }

  void _showObjectDetails(DetectedObject object) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(object.label),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Confidence: ${(object.confidence * 100).toStringAsFixed(1)}%'),
              const SizedBox(height: 8),
              if (object.additionalData != null) ...[
                const Text('Additional Data:'),
                const SizedBox(height: 4),
                ...object.additionalData!.entries.map(
                  (e) => Text('${e.key}: ${e.value}'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
