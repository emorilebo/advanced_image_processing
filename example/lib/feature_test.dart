import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:logging/logging.dart';

class FeatureTest extends StatefulWidget {
  const FeatureTest({super.key});

  @override
  State<FeatureTest> createState() => _FeatureTestState();
}

class _FeatureTestState extends State<FeatureTest> {
  final _logger = Logger('FeatureTest');
  Uint8List? _originalImage;
  Map<String, Uint8List> _processedImages = {};
  List<DetectedObject>? _detectedObjects;
  String _status = "Ready";
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadSampleImage();
  }

  Future<void> _loadSampleImage() async {
    try {
      // Load sample image from assets
      final ByteData data = await rootBundle.load('assets/sample_image.jpg');
      final bytes = data.buffer.asUint8List();
      
      setState(() {
        _originalImage = bytes;
        _status = "Sample image loaded";
      });
    } catch (e) {
      setState(() {
        _status = "Failed to load sample image: $e";
      });
      _logger.severe("Failed to load sample image", e);
    }
  }

  Future<void> _runAllTests() async {
    if (_originalImage == null) {
      setState(() {
        _status = "No image loaded";
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = "Running tests...";
      _processedImages = {};
    });

    try {
      // Test basic filters
      await _testBasicFilters();
      
      // Test advanced filters
      await _testAdvancedFilters();
      
      // Test object detection
      await _testObjectDetection();
      
      setState(() {
        _status = "All tests completed successfully";
        _isProcessing = false;
      });
      
      // Save test results to temp directory
      await _saveResults();
      
    } catch (e) {
      setState(() {
        _status = "Test failed: $e";
        _isProcessing = false;
      });
      _logger.severe("Test failed", e);
    }
  }

  Future<void> _testBasicFilters() async {
    setState(() {
      _status = "Testing basic filters...";
    });
    
    // Test grayscale
    final grayscale = await ImageFilters.applyGrayscale(_originalImage!);
    _processedImages['Grayscale'] = grayscale;
    
    // Test blur
    final blur = await ImageFilters.applyBlur(_originalImage!, 5.0);
    _processedImages['Blur'] = blur;
    
    // Test brightness increase
    final brightnessUp = await ImageFilters.adjustBrightness(_originalImage!, 0.5);
    _processedImages['Brightness+'] = brightnessUp;
    
    // Test brightness decrease
    final brightnessDown = await ImageFilters.adjustBrightness(_originalImage!, -0.5);
    _processedImages['Brightness-'] = brightnessDown;
    
    // Test sepia
    final sepia = await ImageFilters.applySepia(_originalImage!);
    _processedImages['Sepia'] = sepia;
    
    // Test invert
    final invert = await ImageFilters.applyInvert(_originalImage!);
    _processedImages['Invert'] = invert;
    
    setState(() {
      _status = "Basic filters tested successfully";
    });
  }

  Future<void> _testAdvancedFilters() async {
    setState(() {
      _status = "Testing advanced filters...";
    });
    
    // Test vignette
    final vignette = await ImageFilters.applyVignette(
      _originalImage!,
      intensity: 0.7,
      radius: 0.5,
    );
    _processedImages['Vignette'] = vignette;
    
    // Test watercolor
    final watercolor = await ImageFilters.applyWatercolor(
      _originalImage!,
      radius: 5,
      intensity: 0.6,
    );
    _processedImages['Watercolor'] = watercolor;
    
    // Test oil painting
    final oilPainting = await ImageFilters.applyOilPainting(
      _originalImage!,
      radius: 4,
      levels: 20,
    );
    _processedImages['Oil Painting'] = oilPainting;
    
    setState(() {
      _status = "Advanced filters tested successfully";
    });
  }

  Future<void> _testObjectDetection() async {
    setState(() {
      _status = "Testing object detection...";
    });
    
    // Run object detection
    final detections = await ObjectRecognition.detectObjects(_originalImage!);
    
    // Draw detections on image
    final annotatedImage = await ObjectRecognition.drawDetections(
      _originalImage!,
      detections,
    );
    
    setState(() {
      _detectedObjects = detections;
      _processedImages['Object Detection'] = annotatedImage;
      _status = "Object detection tested successfully. Found ${detections.length} objects.";
    });
  }

  Future<void> _saveResults() async {
    final tempDir = await getTemporaryDirectory();
    final testOutputDir = Directory('${tempDir.path}/advanced_image_processing_test');
    
    // Create directory if it doesn't exist
    if (!await testOutputDir.exists()) {
      await testOutputDir.create(recursive: true);
    }
    
    // Save original image
    await File('${testOutputDir.path}/original.jpg').writeAsBytes(_originalImage!);
    
    // Save processed images
    for (final entry in _processedImages.entries) {
      await File('${testOutputDir.path}/${entry.key.toLowerCase().replaceAll(' ', '_')}.jpg')
          .writeAsBytes(entry.value);
    }
    
    // Save detection results
    if (_detectedObjects != null && _detectedObjects!.isNotEmpty) {
      final detectionSummary = StringBuffer();
      detectionSummary.writeln("Object Detection Results:");
      detectionSummary.writeln("=============================");
      
      for (final obj in _detectedObjects!) {
        detectionSummary.writeln("Label: ${obj.label}");
        detectionSummary.writeln("Confidence: ${(obj.confidence * 100).toStringAsFixed(2)}%");
        detectionSummary.writeln("Bounding Box: ${obj.boundingBox}");
        if (obj.additionalData != null) {
          detectionSummary.writeln("Additional Data: ${obj.additionalData}");
        }
        detectionSummary.writeln("-----------------------------");
      }
      
      await File('${testOutputDir.path}/detection_results.txt')
          .writeAsString(detectionSummary.toString());
    }
    
    setState(() {
      _status = "Test results saved to ${testOutputDir.path}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Image Processing Test'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status bar
                    Container(
                      padding: const EdgeInsets.all(8.0),
                      decoration: BoxDecoration(
                        color: _isProcessing ? Colors.blue[100] : Colors.green[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      width: double.infinity,
                      child: Text(
                        _status,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isProcessing ? Colors.blue[900] : Colors.green[900],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Original image
                    if (_originalImage != null) ...[
                      const Text('Original Image:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          _originalImage!,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Processed images
                    if (_processedImages.isNotEmpty) ...[
                      const Text('Processed Images:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _processedImages.length,
                        itemBuilder: (context, index) {
                          final entry = _processedImages.entries.elementAt(index);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.memory(
                                    entry.value,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Text(entry.key),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Detection results
                    if (_detectedObjects != null && _detectedObjects!.isNotEmpty) ...[
                      const Text('Detection Results:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _detectedObjects!.length,
                        itemBuilder: (context, index) {
                          final obj = _detectedObjects![index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Label: ${obj.label}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text('Confidence: ${(obj.confidence * 100).toStringAsFixed(2)}%'),
                                  Text('Bounding Box: (${obj.boundingBox.left.toInt()}, ${obj.boundingBox.top.toInt()}) - '
                                      '${obj.boundingBox.width.toInt()}x${obj.boundingBox.height.toInt()}'),
                                  if (obj.additionalData != null && obj.label == 'Text')
                                    Text('Text: ${obj.additionalData!['text']}'),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          
          // Bottom action bar
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isProcessing ? null : _loadSampleImage,
                  child: const Text('Load Sample'),
                ),
                ElevatedButton(
                  onPressed: _isProcessing ? null : () async {
                    final picker = ImagePicker();
                    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
                    if (pickedFile != null) {
                      final bytes = await pickedFile.readAsBytes();
                      setState(() {
                        _originalImage = bytes;
                        _processedImages = {};
                        _detectedObjects = null;
                        _status = "Image loaded from gallery";
                      });
                    }
                  },
                  child: const Text('Pick Image'),
                ),
                ElevatedButton(
                  onPressed: _isProcessing || _originalImage == null ? null : _runAllTests,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Run All Tests'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 