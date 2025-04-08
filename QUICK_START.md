# Advanced Image Processing Toolkit - Quick Start Guide

This guide will help you quickly get started with the Advanced Image Processing Toolkit for Flutter.

## Installation

1. Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  advanced_image_processing_toolkit: ^0.1.2
```

2. Run:

```bash
flutter pub get
```

3. Import the package:

```dart
import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
```

## Basic Setup

Initialize the toolkit in your app:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the toolkit
  await AdvancedImageProcessingToolkit.initialize();
  
  runApp(MyApp());
}
```

## Image Filtering

### Apply Grayscale Filter

```dart
final imageFilters = ImageFilters();

Future<void> convertToGrayscale(Uint8List imageBytes) async {
  final processedImage = await imageFilters.applyGrayscale(imageBytes);
  // Use processedImage...
}
```

### Apply Blur Filter

```dart
Future<void> applyBlur(Uint8List imageBytes) async {
  final processedImage = await imageFilters.applyBlur(imageBytes, 5.0);
  // Use processedImage...
}
```

### Adjust Brightness

```dart
Future<void> adjustBrightness(Uint8List imageBytes) async {
  final processedImage = await ImageFilters.adjustBrightness(imageBytes, 1.2);
  // Use processedImage...
}
```

## Object Detection

Detect objects in an image:

```dart
Future<void> detectObjects(Uint8List imageBytes) async {
  final detections = await ObjectRecognition.detectObjects(imageBytes);
  
  for (final detection in detections) {
    print('Detected: ${detection.label}');
    print('Confidence: ${detection.confidence}');
    print('Position: ${detection.boundingBox}');
  }
}
```

## Augmented Reality

### Check AR Support

```dart
Future<void> checkARSupport() async {
  final isSupported = await AugmentedReality.isARSupported();
  
  if (isSupported) {
    // Proceed with AR features
  } else {
    // Show alternative UI
  }
}
```

### Start AR Session

```dart
Future<void> startARSession() async {
  final sessionStarted = await AugmentedReality.startARSession();
  
  if (sessionStarted) {
    // AR session is running
  }
}
```

### Place 3D Model

```dart
Future<void> place3DModel() async {
  await AugmentedReality.placeModel(
    modelPath: 'assets/models/robot.glb',
    position: [0.0, 0.0, -1.0],
    scale: 0.5,
    rotation: [0.0, 45.0, 0.0],
  );
}
```

### Stop AR Session

```dart
Future<void> stopARSession() async {
  await AugmentedReality.stopARSession();
}
```

## Complete Example

Here's a simple example that demonstrates image filtering and object detection:

```dart
import 'package:flutter/material.dart';
import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdvancedImageProcessingToolkit.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Processing Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ImageProcessingDemo(),
    );
  }
}

class ImageProcessingDemo extends StatefulWidget {
  @override
  _ImageProcessingDemoState createState() => _ImageProcessingDemoState();
}

class _ImageProcessingDemoState extends State<ImageProcessingDemo> {
  final ImagePicker _picker = ImagePicker();
  final ImageFilters _imageFilters = ImageFilters();
  Uint8List? _imageBytes;
  List<DetectedObject>? _detections;
  
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _detections = null;
      });
    }
  }
  
  Future<void> _applyGrayscale() async {
    if (_imageBytes != null) {
      final processed = await _imageFilters.applyGrayscale(_imageBytes!);
      setState(() {
        _imageBytes = Uint8List.fromList(processed);
      });
    }
  }
  
  Future<void> _detectObjects() async {
    if (_imageBytes != null) {
      final detections = await ObjectRecognition.detectObjects(_imageBytes!);
      setState(() {
        _detections = detections;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Image Processing Demo')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_imageBytes != null) ...[
              Image.memory(
                _imageBytes!,
                height: 300,
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _applyGrayscale,
                    child: Text('Apply Grayscale'),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _detectObjects,
                    child: Text('Detect Objects'),
                  ),
                ],
              ),
            ],
            if (_detections != null) ...[
              SizedBox(height: 20),
              Text('Detected ${_detections!.length} objects'),
              Expanded(
                child: ListView.builder(
                  itemCount: _detections!.length,
                  itemBuilder: (context, index) {
                    final obj = _detections![index];
                    return ListTile(
                      title: Text(obj.label),
                      subtitle: Text('Confidence: ${obj.confidence.toStringAsFixed(2)}'),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickImage,
        child: Icon(Icons.add_photo_alternate),
      ),
    );
  }
}
```

## Next Steps

For more detailed information, check out:

- [Full Documentation](DOCUMENTATION.md)
- [API Reference](API_REFERENCE.md)
- [Example Projects](example/)

## Getting Help

If you encounter any issues:

1. Check the [GitHub issues](https://github.com/emorilebo/advanced_image_processing/issues)
2. Open a new issue with detailed information about your problem

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 