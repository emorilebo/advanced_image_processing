# Advanced Image Processing Toolkit

A comprehensive Flutter package for advanced image processing, featuring real-time filters, object recognition, and AR capabilities.

## Features

### Image Filters
- ✅ Grayscale conversion
- ✅ Gaussian blur
- ✅ Brightness adjustment
- ✅ Sepia tone
- ✅ Color inversion
- ✅ Vignette effect
- ✅ Watercolor effect
- ✅ Oil painting effect
- ✅ Custom filter chains

### Object Recognition
- ✅ Real-time object detection
- ✅ Face detection with landmarks
- ✅ Pose estimation
- ✅ Text recognition (OCR)
- ✅ Multiple object tracking
- ✅ Confidence scoring
- ✅ Bounding box calculation
- ✅ Detailed object information

### Augmented Reality
- ✅ AR session management
- ✅ 3D model placement
- ✅ Surface detection
- ✅ Real-world scale adjustment
- ✅ Platform-specific optimizations

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  advanced_image_processing_toolkit: ^0.1.2
```

For AR features, add these optional dependencies:

```yaml
dependencies:
  arkit_plugin: ^1.0.7 # iOS AR
  arcore_flutter_plugin: ^0.1.0 # Android AR
```

## Usage

### Initialize the Toolkit

```dart
await AdvancedImageProcessingToolkit.initialize(
  enableObjectDetection: true,
  enableAR: true,
);
```

### Apply Image Filters

```dart
// Grayscale
final grayscaleImage = await ImageFilters.applyGrayscale(imageBytes);

// Blur
final blurredImage = await ImageFilters.applyBlur(imageBytes, sigma: 5.0);

// Brightness
final brightImage = await ImageFilters.adjustBrightness(imageBytes, factor: 0.5);

// Sepia
final sepiaImage = await ImageFilters.applySepia(imageBytes);

// Invert
final invertedImage = await ImageFilters.applyInvert(imageBytes);

// Vignette
final vignetteImage = await ImageFilters.applyVignette(
  imageBytes,
  intensity: 0.5,
  radius: 0.5,
);

// Watercolor
final watercolorImage = await ImageFilters.applyWatercolor(
  imageBytes,
  radius: 5,
  intensity: 0.5,
);

// Oil Painting
final oilPaintingImage = await ImageFilters.applyOilPainting(
  imageBytes,
  radius: 4,
  levels: 20,
);
```

### Object Recognition

```dart
// Detect objects
final detections = await ObjectRecognition.detectObjects(imageBytes);

// Draw bounding boxes
final annotatedImage = await ObjectRecognition.drawDetections(
  imageBytes,
  detections,
);

// Access detection details
for (final detection in detections) {
  print('Label: ${detection.label}');
  print('Confidence: ${detection.confidence}');
  print('Bounding Box: ${detection.boundingBox}');
  if (detection.additionalData != null) {
    print('Additional Data: ${detection.additionalData}');
  }
}
```

### Augmented Reality

```dart
// Check AR support
if (AugmentedReality.isARSupported()) {
  // Start AR session
  await AugmentedReality.startARSession();
  
  // Place 3D model
  await AugmentedReality.placeModel(
    modelPath: 'assets/model.glb',
    position: [0, 0, -1],
    scale: 1.0,
    rotation: [0, 0, 0],
  );
  
  // Stop AR session
  await AugmentedReality.stopARSession();
}
```

## Platform Support

- ✅ Android
- ✅ iOS
- ✅ Web (limited features)
- ✅ macOS (limited features)
- ✅ Windows (limited features)
- ✅ Linux (limited features)

## Dependencies

- Flutter SDK: >=3.3.0
- Dart SDK: >=3.0.0
- image: ^4.5.4
- camera: ^0.11.3
- google_ml_kit: ^0.16.2
- image_picker: ^1.0.7
- logging: ^1.2.0
- path_provider: ^2.1.2
- permission_handler: ^11.3.0
- google_mlkit_text_recognition: ^0.10.0
- google_mlkit_face_detection: ^0.8.0
- google_mlkit_pose_detection: ^0.9.0

## Author

**Godfrey Lebo** - Software Developer, Car Racer, Debugger, Clean Architecture Enthusiast

- 📧 Email: [emorylebo@gmail.com](mailto:emorylebo@gmail.com)
- 💼 LinkedIn: [godfreylebo](https://www.linkedin.com/in/godfreylebo/)
- 🌐 Portfolio: [godfreylebo.vercel.app](https://godfreylebo.vercel.app/)
- 🐙 GitHub: [@emorilebo](https://github.com/emorilebo)

> Experienced Senior Fullstack Developer with over 6 years of professional experience specializing in Dart, JavaScript, and Rust. Proven track record of building scalable, high-performance applications.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details. 