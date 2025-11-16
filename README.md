# 🎨 Advanced Image Processing Toolkit

> **Transform images with AI-powered filters, object recognition, and augmented reality**

A comprehensive Flutter package that brings professional-grade image processing capabilities to your mobile apps. Whether you're building a photo editor, AR app, or need intelligent image analysis, this toolkit provides everything you need in one powerful package.

## ✨ What Makes This Toolkit Special?

This isn't just another image filter library. We've built a complete solution that combines:

- **🎭 Rich Filter Library**: From classic effects to artistic transformations
- **🤖 AI-Powered Recognition**: Detect objects, faces, text, and poses in real-time
- **🌐 Augmented Reality**: Place 3D models and create immersive AR experiences
- **⚡ Performance Optimized**: Built for real-time processing on mobile devices
- **🔧 Easy Integration**: Simple API, comprehensive documentation, and production-ready code

Perfect for photo editing apps, AR experiences, accessibility features, or any app that needs intelligent image processing.

## 🚀 Quick Start

### Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  advanced_image_processing_toolkit: ^0.1.3
```

For AR features (optional), add:

```yaml
dependencies:
  arkit_plugin: ^1.0.7      # iOS AR
  arcore_flutter_plugin: ^0.1.0  # Android AR
```

Then run:

```bash
flutter pub get
```

### Initialize the Toolkit

```dart
import 'package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart';

// Initialize with desired features
await AdvancedImageProcessingToolkit.initialize(
  enableObjectDetection: true,  // Enable AI object recognition
  enableAR: true,               // Enable AR capabilities
);
```

## 🎨 Image Filters

Transform your images with a wide range of professional filters.

### Basic Filters

```dart
import 'package:advanced_image_processing_toolkit/src/filters.dart';

// Grayscale - Classic black and white
final grayscaleImage = await ImageFilters.applyGrayscale(imageBytes);

// Blur - Soft focus effect
final blurredImage = await ImageFilters.applyBlur(imageBytes, sigma: 5.0);

// Brightness - Adjust image brightness
final brightImage = await ImageFilters.adjustBrightness(imageBytes, factor: 0.5);

// Sepia - Vintage warm tone
final sepiaImage = await ImageFilters.applySepia(imageBytes);

// Invert - Negative effect
final invertedImage = await ImageFilters.applyInvert(imageBytes);
```

### Advanced Artistic Filters

```dart
// Vignette - Darken edges for dramatic effect
final vignetteImage = await ImageFilters.applyVignette(
  imageBytes,
  intensity: 0.5,  // 0.0 to 1.0
  radius: 0.5,     // 0.0 to 1.0
);

// Watercolor - Artistic watercolor painting effect
final watercolorImage = await ImageFilters.applyWatercolor(
  imageBytes,
  radius: 5,       // Blur radius
  intensity: 0.5,  // Effect intensity
);

// Oil Painting - Classic oil painting effect
final oilPaintingImage = await ImageFilters.applyOilPainting(
  imageBytes,
  radius: 4,       // Brush size
  levels: 20,      // Color quantization levels
);
```

### Filter Chains

Combine multiple filters for unique effects:

```dart
// Apply multiple filters in sequence
var processed = await ImageFilters.applyGrayscale(imageBytes);
processed = await ImageFilters.adjustBrightness(processed, factor: 1.2);
processed = await ImageFilters.applyVignette(processed, intensity: 0.3);
```

## 🤖 Object Recognition

Leverage Google ML Kit's powerful AI to detect and analyze objects in images.

### Object Detection

```dart
import 'package:advanced_image_processing_toolkit/src/object_recognition.dart';

// Detect objects in image
final detections = await ObjectRecognition.detectObjects(imageBytes);

// Process results
for (final detection in detections) {
  print('Found: ${detection.label}');
  print('Confidence: ${detection.confidence}%');
  print('Location: ${detection.boundingBox}');
  
  // Access additional metadata
  if (detection.additionalData != null) {
    print('Details: ${detection.additionalData}');
  }
}
```

### Visualize Detections

```dart
// Draw bounding boxes on image
final annotatedImage = await ObjectRecognition.drawDetections(
  imageBytes,
  detections,
  boxColor: Colors.red,
  labelColor: Colors.white,
);
```

### Face Detection

```dart
// Detect faces with landmarks
final faceDetections = await ObjectRecognition.detectFaces(imageBytes);

for (final face in faceDetections) {
  print('Face detected at: ${face.boundingBox}');
  // Access facial landmarks, expressions, etc.
}
```

### Text Recognition (OCR)

```dart
// Extract text from images
final textDetections = await ObjectRecognition.recognizeText(imageBytes);

for (final textBlock in textDetections) {
  print('Text: ${textBlock.text}');
  print('Confidence: ${textBlock.confidence}');
  print('Language: ${textBlock.language}');
}
```

### Pose Estimation

```dart
// Detect human poses
final poseDetections = await ObjectRecognition.detectPoses(imageBytes);

for (final pose in poseDetections) {
  // Access body landmarks (shoulders, elbows, knees, etc.)
  final landmarks = pose.landmarks;
  // Use for fitness apps, motion tracking, etc.
}
```

## 🌐 Augmented Reality

Create immersive AR experiences with 3D model placement and surface detection.

### Basic AR Setup

```dart
import 'package:advanced_image_processing_toolkit/src/augmented_reality.dart';

// Check if AR is supported on device
if (AugmentedReality.isARSupported()) {
  // Start AR session
  await AugmentedReality.startARSession();
  
  // Place 3D model in AR space
  await AugmentedReality.placeModel(
    modelPath: 'assets/models/chair.glb',
    position: [0, 0, -1],  // x, y, z coordinates
    scale: 1.0,
    rotation: [0, 0, 0],   // x, y, z rotation
  );
  
  // Stop AR session when done
  await AugmentedReality.stopARSession();
}
```

### Surface Detection

```dart
// Detect horizontal surfaces (tables, floors, etc.)
final surfaces = await AugmentedReality.detectSurfaces();

for (final surface in surfaces) {
  print('Surface detected at: ${surface.position}');
  print('Size: ${surface.size}');
  
  // Place objects on detected surfaces
  await AugmentedReality.placeModel(
    modelPath: 'assets/models/object.glb',
    position: surface.position,
  );
}
```

## 💡 Real-World Use Cases

### Photo Editing App

```dart
// User selects filter
final filteredImage = await ImageFilters.applySepia(userImage);

// Apply additional effects
final finalImage = await ImageFilters.applyVignette(
  filteredImage,
  intensity: 0.3,
);
```

### Accessibility App

```dart
// Extract text from images for visually impaired users
final text = await ObjectRecognition.recognizeText(imageBytes);
speakText(text); // Text-to-speech
```

### E-commerce AR

```dart
// Let users visualize products in their space
await AugmentedReality.placeModel(
  modelPath: 'assets/products/sofa.glb',
  position: [0, 0, -2],
  scale: 1.0,
);
```

### Fitness App

```dart
// Track user's pose during exercises
final poses = await ObjectRecognition.detectPoses(cameraFrame);
analyzeExerciseForm(poses);
```

## 📱 Platform Support

| Platform | Filters | Object Recognition | AR |
|----------|---------|-------------------|-----|
| Android  | ✅      | ✅                | ✅  |
| iOS      | ✅      | ✅                | ✅  |
| Web      | ✅      | ⚠️ Limited        | ❌  |
| macOS    | ✅      | ⚠️ Limited        | ❌  |
| Windows  | ✅      | ⚠️ Limited        | ❌  |
| Linux    | ✅      | ⚠️ Limited        | ❌  |

## 🔧 Configuration & Dependencies

### Required Dependencies

- Flutter SDK: >=3.3.0
- Dart SDK: >=3.0.0

### Core Dependencies

- `image: ^4.5.4` - Image processing
- `camera: ^0.11.3` - Camera access
- `google_ml_kit: ^0.16.2` - ML Kit integration
- `image_picker: ^1.0.7` - Image selection
- `permission_handler: ^11.3.0` - Permissions

### ML Kit Dependencies

- `google_mlkit_text_recognition: ^0.10.0`
- `google_mlkit_face_detection: ^0.8.0`
- `google_mlkit_pose_detection: ^0.9.0`

### Optional AR Dependencies

- `arkit_plugin: ^1.0.7` (iOS)
- `arcore_flutter_plugin: ^0.1.0` (Android)

## ⚡ Performance Tips

1. **Process Images in Background**
   ```dart
   final processed = await compute(ImageFilters.applyGrayscale, imageBytes);
   ```

2. **Cache Processed Images**
   ```dart
   final cacheKey = 'filtered_${imageHash}_sepia';
   if (cache.containsKey(cacheKey)) {
     return cache[cacheKey];
   }
   ```

3. **Resize Before Processing**
   ```dart
   final resized = await resizeImage(imageBytes, maxWidth: 1920);
   final processed = await ImageFilters.applyBlur(resized);
   ```

4. **Use Isolates for Heavy Processing**
   ```dart
   final result = await Isolate.run(() => 
     ImageFilters.applyOilPainting(largeImage)
   );
   ```

## 🐛 Troubleshooting

### Filters Not Working

- ✅ Ensure image format is supported (JPEG, PNG)
- ✅ Check image file size (very large images may cause memory issues)
- ✅ Verify image bytes are valid

### Object Recognition Fails

- ✅ Check camera permissions
- ✅ Ensure Google Play Services (Android) or ML Kit is available
- ✅ Verify image quality (blurry images reduce accuracy)

### AR Not Working

- ✅ Check device AR support: `AugmentedReality.isARSupported()`
- ✅ Verify AR dependencies are added
- ✅ Ensure proper permissions (camera, location for AR)

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run specific test suite
flutter test test/filters_test.dart
flutter test test/object_recognition_test.dart
```

## 📚 API Reference

For detailed API documentation, see [API_REFERENCE.md](API_REFERENCE.md).

## 👨‍💻 Author

**Godfrey Lebo** - Fullstack Developer & Technical PM

> With **9+ years of industry experience**, I specialize in building AI-powered applications, scalable mobile solutions, and secure backend systems. I've led teams delivering marketplaces, fintech platforms, and AI applications serving thousands of users.

- 📧 **Email**: [emorylebo@gmail.com](mailto:emorylebo@gmail.com)
- 💼 **LinkedIn**: [godfreylebo](https://www.linkedin.com/in/godfreylebo/)
- 🌐 **Portfolio**: [godfreylebo.dev](https://www.godfreylebo.dev/)
- 🐙 **GitHub**: [@emorilebo](https://github.com/emorilebo)

## 🤝 Contributing

We welcome contributions! Whether you're fixing bugs, adding features, or improving documentation, your help makes this toolkit better for everyone.

**Ways to contribute:**
- 🐛 Report bugs
- 💡 Suggest new features
- 📝 Improve documentation
- 🔧 Submit pull requests

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Google ML Kit for powerful AI capabilities
- Flutter team for the amazing framework
- Community contributors and users

---

**Made with ❤️ by [Godfrey Lebo](https://www.godfreylebo.dev/)**

If this toolkit helps build your app, consider giving it a ⭐ on GitHub!
