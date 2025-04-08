# Advanced Image Processing Toolkit - API Reference

This document provides a detailed reference of all classes, methods, and parameters available in the Advanced Image Processing Toolkit (version 0.1.2).

## Table of Contents

- [AdvancedImageProcessingToolkit](#advancedimageprocessingtoolkit)
- [ImageFilters](#imagefilters)
- [ObjectRecognition](#objectrecognition)
- [DetectedObject](#detectedobject)
- [AugmentedReality](#augmentedreality)

## AdvancedImageProcessingToolkit

The main class that provides access to the toolkit's functionality.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `version` | `String` | The current version of the toolkit |

### Methods

#### `initialize`

Initializes the toolkit with optional configuration.

```dart
static Future<void> initialize({
  bool enableObjectDetection = true,
  bool enableAR = true,
})
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enableObjectDetection` | `bool` | `true` | Whether to initialize object detection capabilities |
| `enableAR` | `bool` | `true` | Whether to initialize augmented reality capabilities |

**Returns:** `Future<void>` - Completes when initialization is done

**Example:**

```dart
await AdvancedImageProcessingToolkit.initialize(
  enableObjectDetection: true,
  enableAR: false, // Disable AR if not needed
);
```

#### `getPlatformVersion`

Gets the current platform version.

```dart
Future<String?> getPlatformVersion()
```

**Returns:** `Future<String?>` - The platform version string

**Example:**

```dart
final version = await AdvancedImageProcessingToolkit().getPlatformVersion();
print('Running on: $version');
```

## ImageFilters

Provides image filtering capabilities.

### Methods

#### `applyGrayscale`

Converts an image to grayscale.

```dart
Future<List<int>> applyGrayscale(List<int> imageData)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `imageData` | `List<int>` | The raw image data as bytes |

**Returns:** `Future<List<int>>` - The processed image data

**Example:**

```dart
final imageFilters = ImageFilters();
final processedImage = await imageFilters.applyGrayscale(originalImageBytes);
```

#### `applyBlur`

Applies a Gaussian blur to an image.

```dart
Future<List<int>> applyBlur(List<int> imageData, double sigma)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `imageData` | `List<int>` | The raw image data as bytes |
| `sigma` | `double` | The blur intensity (higher values = more blur) |

**Returns:** `Future<List<int>>` - The processed image data

**Example:**

```dart
final imageFilters = ImageFilters();
final processedImage = await imageFilters.applyBlur(originalImageBytes, 5.0);
```

#### `adjustBrightness`

Adjusts the brightness of an image.

```dart
static Future<Uint8List> adjustBrightness(Uint8List imageBytes, double factor)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `imageBytes` | `Uint8List` | The image data as bytes |
| `factor` | `double` | The brightness factor (1.0 = original, >1.0 = brighter, <1.0 = darker) |

**Returns:** `Future<Uint8List>` - The processed image data

**Example:**

```dart
// Increase brightness by 20%
final processedImage = await ImageFilters.adjustBrightness(originalImageBytes, 1.2);

// Decrease brightness by 30%
final darkerImage = await ImageFilters.adjustBrightness(originalImageBytes, 0.7);
```

## ObjectRecognition

Provides object detection and recognition capabilities.

### Methods

#### `detectObjects`

Detects objects in an image.

```dart
static Future<List<DetectedObject>> detectObjects(Uint8List imageBytes)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `imageBytes` | `Uint8List` | The image data as bytes |

**Returns:** `Future<List<DetectedObject>>` - A list of detected objects

**Example:**

```dart
final detections = await ObjectRecognition.detectObjects(imageBytes);

for (final detection in detections) {
  print('Detected: ${detection.label}');
  print('Confidence: ${detection.confidence}');
  print('Position: ${detection.boundingBox}');
}
```

## DetectedObject

Represents an object detected in an image.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `label` | `String` | The name/class of the detected object |
| `confidence` | `double` | Confidence score (0.0 to 1.0) |
| `boundingBox` | `Rect` | Position and size of the object in the image |

### Constructor

```dart
DetectedObject({
  required String label,
  required double confidence,
  required Rect boundingBox,
})
```

### Factory Methods

#### `fromMap`

Creates a `DetectedObject` from a map.

```dart
factory DetectedObject.fromMap(Map<dynamic, dynamic> map)
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `map` | `Map<dynamic, dynamic>` | Map containing object data |

**Returns:** `DetectedObject` - A new instance

## AugmentedReality

Provides augmented reality capabilities.

### Methods

#### `isARSupported`

Checks if AR is supported on the current device.

```dart
static Future<bool> isARSupported()
```

**Returns:** `Future<bool>` - `true` if AR is supported, `false` otherwise

**Example:**

```dart
final isSupported = await AugmentedReality.isARSupported();

if (isSupported) {
  // Proceed with AR features
} else {
  // Show alternative UI
}
```

#### `startARSession`

Starts an AR session.

```dart
static Future<bool> startARSession()
```

**Returns:** `Future<bool>` - `true` if session started successfully, `false` otherwise

**Example:**

```dart
final sessionStarted = await AugmentedReality.startARSession();

if (sessionStarted) {
  // AR session is running
}
```

#### `stopARSession`

Stops the current AR session.

```dart
static Future<bool> stopARSession()
```

**Returns:** `Future<bool>` - `true` if session stopped successfully, `false` otherwise

**Example:**

```dart
final sessionStopped = await AugmentedReality.stopARSession();
```

#### `placeModel`

Places a 3D model in the AR scene.

```dart
static Future<bool> placeModel({
  required String modelPath,
  required List<double> position,
  double scale = 1.0,
  List<double> rotation = const [0.0, 0.0, 0.0],
})
```

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `modelPath` | `String` | (required) | Path to the 3D model file |
| `position` | `List<double>` | (required) | Position in 3D space [x, y, z] |
| `scale` | `double` | `1.0` | Scale factor (1.0 = original size) |
| `rotation` | `List<double>` | `[0.0, 0.0, 0.0]` | Rotation in degrees [x, y, z] |

**Returns:** `Future<bool>` - `true` if model placed successfully, `false` otherwise

**Example:**

```dart
final modelPlaced = await AugmentedReality.placeModel(
  modelPath: 'assets/models/robot.glb',
  position: [0.0, 0.0, -1.0],
  scale: 0.5,
  rotation: [0.0, 45.0, 0.0],
);
```

## Error Handling

All methods in the toolkit can throw exceptions. It's recommended to wrap calls in try-catch blocks:

```dart
try {
  final result = await someToolkitMethod();
  // Process result
} catch (e) {
  print('Error: $e');
  // Handle error
}
```

Common exceptions include:

- `PlatformException`: Thrown when there's an error in the native platform code
- `ArgumentError`: Thrown when invalid arguments are provided
- `StateError`: Thrown when a method is called in an invalid state

## Platform-specific Notes

### Android

- AR features require ARCore support
- Minimum SDK version: 21 (Android 5.0)

### iOS

- AR features require ARKit support (iOS 11.0+)
- Minimum iOS version: 11.0

---

This API reference is based on version 0.0.6 of the Advanced Image Processing Toolkit. For the latest documentation, please refer to the [GitHub repository](https://github.com/emorilebo/advanced_image_processing). 