# Advanced Image Processing Toolkit - Documentation

This document provides detailed information on how to use the Advanced Image Processing Toolkit (version 0.1.2) for Flutter. It covers installation, configuration, and usage of all major features.

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Image Filtering](#image-filtering)
- [Object Detection](#object-detection)
- [Augmented Reality](#augmented-reality)
- [Advanced Usage](#advanced-usage)
- [Performance Optimization](#performance-optimization)
- [Troubleshooting](#troubleshooting)

## Installation

### Basic Installation

Add the dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  advanced_image_processing_toolkit: ^0.0.10
```

Run:

```bash
flutter pub get
```

### Platform-specific Setup

#### Android

1. Ensure your `minSdkVersion` is at least 21 in your `android/app/build.gradle` file:

```gradle
android {
    defaultConfig {
        minSdkVersion 21
        // other configurations...
    }
}
```

2. Add the following permissions to your `AndroidManifest.xml`:

```xml
<!-- For basic image processing -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />

<!-- For camera access -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- For AR features -->
<uses-feature android:name="android.hardware.camera.ar" />
```

3. For AR features, add the following to your `android/app/build.gradle` dependencies:

```gradle
dependencies {
    // other dependencies...
    implementation 'com.google.ar:core:1.25.0'
}
```

#### iOS

1. Update your `ios/Podfile` to set the minimum iOS version:

```ruby
platform :ios, '11.0'
```

2. Add the following to your `Info.plist`:

```xml
<!-- Camera permissions -->
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for image processing and AR features</string>

<!-- Photo library permissions -->
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to process your images</string>

<!-- For AR features -->
<key>NSCameraUsageDescription</key>
<string>This app uses the camera for Augmented Reality features</string>
```

3. For AR features, add ARKit capability in Xcode:
   - Open your project in Xcode
   - Select your target
   - Go to "Signing & Capabilities"
   - Click "+" and add "ARKit"

## Configuration

### Initializing the Toolkit

Initialize the toolkit early in your app's lifecycle:

```dart
import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';

Future<void> initializeToolkit() async {
  await AdvancedImageProcessingToolkit.initialize(
    enableObjectDetection: true, // Set to false if not needed
    enableAR: true, // Set to false if not needed
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeToolkit();
  runApp(MyApp());
}
```

### Configuration Options

The `initialize` method accepts several parameters:

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enableObjectDetection` | `bool` | `true` | Enable/disable object detection features |
| `enableAR` | `bool` | `true` | Enable/disable augmented reality features |

## Image Filtering

The toolkit provides various image filtering capabilities through the `ImageFilters` class.

### Creating an Instance

```dart
import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';

final imageFilters = ImageFilters();
```

### Available Filters

#### Grayscale

Converts a color image to grayscale:

```dart
Future<void> convertToGrayscale() async {
  // Get image bytes from file, asset, or network
  final Uint8List originalImageBytes = await _getImageBytes();
  
  // Apply grayscale filter
  final List<int> processedImageBytes = await imageFilters.applyGrayscale(originalImageBytes);
  
  // Convert back to Uint8List if needed
  final Uint8List result = Uint8List.fromList(processedImageBytes);
  
  // Use the processed image (display, save, etc.)
  setState(() {
    _displayImage = result;
  });
}
```

#### Gaussian Blur

Applies a blur effect to an image:

```dart
Future<void> applyBlurEffect() async {
  final Uint8List originalImageBytes = await _getImageBytes();
  
  // Apply blur with sigma value (controls blur intensity)
  // Lower values (e.g., 1.0) for subtle blur
  // Higher values (e.g., 10.0) for stronger blur
  final List<int> processedImageBytes = await imageFilters.applyBlur(
    originalImageBytes, 
    5.0 // sigma value
  );
  
  final Uint8List result = Uint8List.fromList(processedImageBytes);
  
  setState(() {
    _displayImage = result;
  });
}
```

#### Brightness Adjustment

Adjusts the brightness of an image:

```dart
Future<void> adjustImageBrightness() async {
  final Uint8List originalImageBytes = await _getImageBytes();
  
  // Adjust brightness with factor:
  // Values > 1.0 increase brightness (e.g., 1.5 = 50% brighter)
  // Values < 1.0 decrease brightness (e.g., 0.7 = 30% darker)
  final Uint8List result = await ImageFilters.adjustBrightness(
    originalImageBytes,
    1.2 // brightness factor
  );
  
  setState(() {
    _displayImage = result;
  });
}
```

### Chaining Multiple Filters

You can apply multiple filters in sequence:

```dart
Future<void> applyMultipleFilters() async {
  final Uint8List originalImageBytes = await _getImageBytes();
  
  // First apply grayscale
  final List<int> grayscaleImage = await imageFilters.applyGrayscale(originalImageBytes);
  
  // Then apply blur to the grayscale image
  final List<int> processedImageBytes = await imageFilters.applyBlur(
    grayscaleImage,
    3.0
  );
  
  final Uint8List result = Uint8List.fromList(processedImageBytes);
  
  setState(() {
    _displayImage = result;
  });
}
```

### Processing Images from Different Sources

#### From Asset

```dart
Future<Uint8List> getImageBytesFromAsset(String assetPath) async {
  final ByteData data = await rootBundle.load(assetPath);
  return data.buffer.asUint8List();
}
```

#### From File

```dart
Future<Uint8List> getImageBytesFromFile(File file) async {
  return await file.readAsBytes();
}
```

#### From Network

```dart
Future<Uint8List> getImageBytesFromNetwork(String url) async {
  final http.Response response = await http.get(Uri.parse(url));
  return response.bodyBytes;
}
```

## Object Detection

The toolkit provides object detection capabilities through the `ObjectRecognition` class.

### Basic Object Detection

```dart
import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'dart:typed_data';

Future<void> detectObjects() async {
  // Get image bytes
  final Uint8List imageBytes = await _getImageBytes();
  
  // Perform object detection
  final List<DetectedObject> detectedObjects = await ObjectRecognition.detectObjects(imageBytes);
  
  // Process detection results
  for (final DetectedObject object in detectedObjects) {
    print('Detected: ${object.label}');
    print('Confidence: ${object.confidence}');
    print('Position: ${object.boundingBox}');
  }
}
```

### Working with Detection Results

The `DetectedObject` class provides information about each detected object:

```dart
void processDetectionResults(List<DetectedObject> detections) {
  for (final detection in detections) {
    // Get the object label (e.g., "person", "car", "dog")
    final String label = detection.label;
    
    // Get the confidence score (0.0 to 1.0)
    final double confidence = detection.confidence;
    
    // Get the bounding box (position and size)
    final Rect boundingBox = detection.boundingBox;
    
    // Extract coordinates
    final double left = boundingBox.left;
    final double top = boundingBox.top;
    final double width = boundingBox.width;
    final double height = boundingBox.height;
    
    // Use this information to draw bounding boxes, show labels, etc.
  }
}
```

### Drawing Bounding Boxes

To visualize detected objects, you can draw bounding boxes on the image:

```dart
import 'package:flutter/material.dart';

class ObjectDetectionPainter extends CustomPainter {
  final List<DetectedObject> detections;
  final Size imageSize;
  
  ObjectDetectionPainter({required this.detections, required this.imageSize});
  
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;
      
    final Paint textBgPaint = Paint()
      ..color = Colors.red.withOpacity(0.7)
      ..style = PaintingStyle.fill;
      
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;
    
    for (final detection in detections) {
      // Scale the bounding box to match the display size
      final Rect scaledRect = Rect.fromLTWH(
        detection.boundingBox.left * scaleX,
        detection.boundingBox.top * scaleY,
        detection.boundingBox.width * scaleX,
        detection.boundingBox.height * scaleY,
      );
      
      // Draw the bounding box
      canvas.drawRect(scaledRect, paint);
      
      // Draw the label
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      );
      
      final textSpan = TextSpan(
        text: '${detection.label} ${(detection.confidence * 100).toStringAsFixed(0)}%',
        style: textStyle,
      );
      
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      // Draw text background
      canvas.drawRect(
        Rect.fromLTWH(
          scaledRect.left,
          scaledRect.top - textPainter.height - 4,
          textPainter.width + 8,
          textPainter.height + 4,
        ),
        textBgPaint,
      );
      
      // Draw text
      textPainter.paint(
        canvas,
        Offset(scaledRect.left + 4, scaledRect.top - textPainter.height - 2),
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
```

Usage in a widget:

```dart
Widget buildDetectionOverlay(Uint8List imageBytes, List<DetectedObject> detections) {
  return Stack(
    children: [
      Image.memory(imageBytes),
      CustomPaint(
        painter: ObjectDetectionPainter(
          detections: detections,
          imageSize: Size(imageWidth, imageHeight), // You need to know the original image dimensions
        ),
        size: Size(displayWidth, displayHeight), // The size at which the image is displayed
      ),
    ],
  );
}
```

### Real-time Detection with Camera Feed

For real-time object detection using the camera:

```dart
import 'package:camera/camera.dart';

class RealTimeDetectionScreen extends StatefulWidget {
  @override
  _RealTimeDetectionScreenState createState() => _RealTimeDetectionScreenState();
}

class _RealTimeDetectionScreenState extends State<RealTimeDetectionScreen> {
  late CameraController _cameraController;
  List<DetectedObject>? _detections;
  bool _isProcessing = false;
  
  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }
  
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;
    
    _cameraController = CameraController(
      firstCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    
    await _cameraController.initialize();
    
    _cameraController.startImageStream((CameraImage image) {
      if (!_isProcessing) {
        _processImage(image);
      }
    });
    
    setState(() {});
  }
  
  Future<void> _processImage(CameraImage image) async {
    _isProcessing = true;
    
    // Convert CameraImage to Uint8List (implementation depends on platform)
    final Uint8List bytes = await _convertCameraImageToBytes(image);
    
    // Perform detection
    final detections = await ObjectRecognition.detectObjects(bytes);
    
    setState(() {
      _detections = detections;
      _isProcessing = false;
    });
  }
  
  // This is a placeholder - actual implementation depends on platform
  Future<Uint8List> _convertCameraImageToBytes(CameraImage image) async {
    // Implementation details depend on platform and image format
    // This is a complex topic that requires platform-specific code
    // ...
    
    return Uint8List(0); // Placeholder
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_cameraController.value.isInitialized) {
      return Center(child: CircularProgressIndicator());
    }
    
    return Stack(
      children: [
        CameraPreview(_cameraController),
        if (_detections != null)
          CustomPaint(
            painter: ObjectDetectionPainter(
              detections: _detections!,
              imageSize: Size(
                _cameraController.value.previewSize!.height,
                _cameraController.value.previewSize!.width,
              ),
            ),
            size: Size(
              MediaQuery.of(context).size.width,
              MediaQuery.of(context).size.height,
            ),
          ),
      ],
    );
  }
  
  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }
}
```

## Augmented Reality

The toolkit provides augmented reality capabilities through the `AugmentedReality` class.

### Checking AR Support

Before using AR features, check if the device supports AR:

```dart
Future<void> checkARSupport() async {
  final bool isSupported = await AugmentedReality.isARSupported();
  
  if (isSupported) {
    print('AR is supported on this device');
    // Proceed with AR features
  } else {
    print('AR is not supported on this device');
    // Show alternative UI or disable AR features
  }
}
```

### Basic AR Session

Starting and stopping an AR session:

```dart
Future<void> manageARSession() async {
  // Start AR session
  final bool sessionStarted = await AugmentedReality.startARSession();
  
  if (sessionStarted) {
    print('AR session started successfully');
    
    // Use AR features...
    
    // When done, stop the session
    final bool sessionStopped = await AugmentedReality.stopARSession();
    
    if (sessionStopped) {
      print('AR session stopped successfully');
    } else {
      print('Failed to stop AR session');
    }
  } else {
    print('Failed to start AR session');
  }
}
```

### Placing 3D Models

Place 3D models in the AR scene:

```dart
Future<void> place3DModel() async {
  // Ensure AR session is running
  final bool sessionStarted = await AugmentedReality.startARSession();
  
  if (sessionStarted) {
    // Place a 3D model
    final bool modelPlaced = await AugmentedReality.placeModel(
      modelPath: 'assets/models/robot.glb', // Path to your 3D model
      position: [0.0, 0.0, -1.0], // Position in 3D space [x, y, z]
      scale: 0.5, // Scale factor (1.0 = original size)
      rotation: [0.0, 45.0, 0.0], // Rotation in degrees [x, y, z]
    );
    
    if (modelPlaced) {
      print('3D model placed successfully');
    } else {
      print('Failed to place 3D model');
    }
  }
}
```

### Creating an AR View

To display AR content, you need to create an AR view in your UI:

```dart
import 'package:flutter/material.dart';
import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';

class ARViewScreen extends StatefulWidget {
  @override
  _ARViewScreenState createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen> {
  bool _isARSupported = false;
  bool _isSessionRunning = false;
  
  @override
  void initState() {
    super.initState();
    _checkARSupport();
  }
  
  Future<void> _checkARSupport() async {
    final isSupported = await AugmentedReality.isARSupported();
    
    setState(() {
      _isARSupported = isSupported;
    });
    
    if (_isARSupported) {
      _startARSession();
    }
  }
  
  Future<void> _startARSession() async {
    final sessionStarted = await AugmentedReality.startARSession();
    
    setState(() {
      _isSessionRunning = sessionStarted;
    });
  }
  
  Future<void> _placeRobot() async {
    if (_isSessionRunning) {
      await AugmentedReality.placeModel(
        modelPath: 'assets/models/robot.glb',
        position: [0.0, 0.0, -1.0],
        scale: 0.5,
        rotation: [0.0, 0.0, 0.0],
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isARSupported) {
      return Scaffold(
        appBar: AppBar(title: Text('AR Demo')),
        body: Center(
          child: Text('AR is not supported on this device'),
        ),
      );
    }
    
    if (!_isSessionRunning) {
      return Scaffold(
        appBar: AppBar(title: Text('AR Demo')),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(title: Text('AR Demo')),
      body: Stack(
        children: [
          // AR View would be provided by the native platform
          // This is a placeholder - the actual implementation
          // depends on how the AR view is exposed to Flutter
          Container(
            color: Colors.black,
            child: Center(
              child: Text(
                'AR View',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          
          // UI controls
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _placeRobot,
                  child: Text('Place Robot'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    if (_isSessionRunning) {
      AugmentedReality.stopARSession();
    }
    super.dispose();
  }
}
```

### Supported 3D Model Formats

The toolkit supports the following 3D model formats:

- GLB (recommended)
- GLTF
- OBJ (with MTL)

For best performance and compatibility, use GLB format.

## Advanced Usage

### Custom Image Processing

For advanced users who need custom image processing:

```dart
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';

class CustomImageProcessor {
  static const MethodChannel _channel = MethodChannel('advanced_image_processing_toolkit/custom');
  
  // Example of a custom processing method
  static Future<Uint8List> applyCustomFilter(
    Uint8List imageBytes,
    Map<String, dynamic> parameters,
  ) async {
    try {
      final result = await _channel.invokeMethod<Uint8List>(
        'applyCustomFilter',
        {
          'imageBytes': imageBytes,
          'parameters': parameters,
        },
      );
      
      return result ?? imageBytes;
    } catch (e) {
      print('Error applying custom filter: $e');
      return imageBytes;
    }
  }
  
  // Example of combining multiple filters
  static Future<Uint8List> applyFilterChain(
    Uint8List imageBytes,
    List<Map<String, dynamic>> filterChain,
  ) async {
    Uint8List currentImage = imageBytes;
    final imageFilters = ImageFilters();
    
    for (final filter in filterChain) {
      final String filterType = filter['type'];
      
      switch (filterType) {
        case 'grayscale':
          final processed = await imageFilters.applyGrayscale(currentImage);
          currentImage = Uint8List.fromList(processed);
          break;
          
        case 'blur':
          final double sigma = filter['sigma'] ?? 5.0;
          final processed = await imageFilters.applyBlur(currentImage, sigma);
          currentImage = Uint8List.fromList(processed);
          break;
          
        case 'brightness':
          final double factor = filter['factor'] ?? 1.0;
          currentImage = await ImageFilters.adjustBrightness(currentImage, factor);
          break;
          
        case 'custom':
          final Map<String, dynamic> params = filter['parameters'] ?? {};
          currentImage = await applyCustomFilter(currentImage, params);
          break;
      }
    }
    
    return currentImage;
  }
}
```

Usage example:

```dart
Future<void> applyFilterChain() async {
  final Uint8List originalImage = await _getImageBytes();
  
  final Uint8List processedImage = await CustomImageProcessor.applyFilterChain(
    originalImage,
    [
      {'type': 'grayscale'},
      {'type': 'blur', 'sigma': 3.0},
      {'type': 'brightness', 'factor': 1.2},
      {
        'type': 'custom',
        'parameters': {
          'contrast': 1.5,
          'saturation': 0.8,
        },
      },
    ],
  );
  
  setState(() {
    _displayImage = processedImage;
  });
}
```

### Custom Object Detection Models

For specialized object detection needs, you can use custom models:

```dart
import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';

class CustomObjectDetection {
  static Future<void> loadCustomModel(String modelPath) async {
    try {
      await ObjectRecognition.loadCustomModel(modelPath);
      print('Custom model loaded successfully');
    } catch (e) {
      print('Error loading custom model: $e');
    }
  }
  
  static Future<List<DetectedObject>> detectWithCustomModel(
    Uint8List imageBytes,
    {double confidenceThreshold = 0.5}
  ) async {
    try {
      final detections = await ObjectRecognition.detectWithCustomModel(
        imageBytes,
        confidenceThreshold: confidenceThreshold,
      );
      
      return detections;
    } catch (e) {
      print('Error detecting with custom model: $e');
      return [];
    }
  }
}
```

## Performance Optimization

### Image Resizing

For better performance, resize large images before processing:

```dart
import 'package:image/image.dart' as img;

Future<Uint8List> resizeImage(Uint8List imageBytes, int targetWidth) async {
  // Decode the image
  final img.Image? originalImage = img.decodeImage(imageBytes);
  
  if (originalImage == null) {
    return imageBytes;
  }
  
  // Calculate target height to maintain aspect ratio
  final double aspectRatio = originalImage.width / originalImage.height;
  final int targetHeight = (targetWidth / aspectRatio).round();
  
  // Resize the image
  final img.Image resizedImage = img.copyResize(
    originalImage,
    width: targetWidth,
    height: targetHeight,
  );
  
  // Encode the image back to bytes
  final Uint8List resizedBytes = Uint8List.fromList(img.encodeJpg(resizedImage));
  
  return resizedBytes;
}
```

### Batch Processing

For processing multiple images, consider using batch processing:

```dart
Future<List<Uint8List>> batchProcessImages(
  List<Uint8List> images,
  Future<Uint8List> Function(Uint8List) processor,
) async {
  final List<Uint8List> results = [];
  
  for (final image in images) {
    final processed = await processor(image);
    results.add(processed);
  }
  
  return results;
}

// Usage example
Future<void> processMultipleImages() async {
  final List<Uint8List> imageList = await _getMultipleImages();
  
  final List<Uint8List> processedImages = await batchProcessImages(
    imageList,
    (image) async {
      // Resize for better performance
      final resized = await resizeImage(image, 800);
      
      // Apply grayscale
      final List<int> grayscale = await imageFilters.applyGrayscale(resized);
      
      return Uint8List.fromList(grayscale);
    },
  );
  
  // Use processed images
  setState(() {
    _processedImageList = processedImages;
  });
}
```

### Memory Management

For handling large images or processing many images:

```dart
Future<void> processLargeImage() async {
  Uint8List? originalImage;
  Uint8List? processedImage;
  
  try {
    // Load image
    originalImage = await _getImageBytes();
    
    // Process image
    final List<int> processed = await imageFilters.applyGrayscale(originalImage);
    processedImage = Uint8List.fromList(processed);
    
    // Use processed image
    _saveProcessedImage(processedImage);
  } finally {
    // Explicitly clear references to large objects
    originalImage = null;
    processedImage = null;
  }
}
```

## Troubleshooting

### Common Errors

#### "PlatformException: No implementation found for method X"

This error occurs when a method is called but not implemented on the current platform.

**Solution**: Check if the feature is supported on your platform and ensure you've completed all platform-specific setup steps.

#### "Out of memory" errors

This can happen when processing very large images.

**Solution**: Resize images before processing or use memory management techniques as shown in the Performance Optimization section.

#### AR features not working

**Solution**:
1. Ensure the device supports ARCore (Android) or ARKit (iOS)
2. Check that you've added all required permissions and dependencies
3. Verify that you're testing on a physical device (AR often doesn't work in simulators/emulators)

### Debugging Tips

#### Enable Verbose Logging

```dart
import 'package:logging/logging.dart';

void setupLogging() {
  Logger.root.level = Level.ALL; // Set to Level.INFO in production
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
}
```

#### Check Platform Support

```dart
Future<void> checkPlatformSupport() async {
  final String? platformVersion = await AdvancedImageProcessingToolkit().getPlatformVersion();
  print('Running on platform: $platformVersion');
  
  final bool arSupported = await AugmentedReality.isARSupported();
  print('AR supported: $arSupported');
}
```

### Getting Help

If you encounter issues not covered in this documentation:

1. Check the [GitHub issues](https://github.com/emorilebo/advanced_image_processing/issues) for similar problems
2. Open a new issue with detailed information:
   - Device model and OS version
   - Flutter and Dart versions
   - Complete error message and stack trace
   - Steps to reproduce the issue
   - Sample code demonstrating the problem

---

This documentation is continuously updated. For the latest version, please visit the [GitHub repository](https://github.com/emorilebo/advanced_image_processing).

Last updated: February 2024 