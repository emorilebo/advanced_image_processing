# API Reference — advanced_image_processing_toolkit

Reference for **v0.2.0**. All filter methods are **static** and return
`Future<Uint8List>`.

## Contents

- [AdvancedImageProcessingToolkit](#advancedimageprocessingtoolkit)
- [ImageFilters](#imagefilters)
- [ObjectRecognition](#objectrecognition)
- [DetectedObject](#detectedobject)
- [AugmentedReality](#augmentedreality)

---

## AdvancedImageProcessingToolkit

Top-level toolkit entry point.

### Constants

| Member | Type | Description |
| --- | --- | --- |
| `version` | `String` | Package version (`"0.2.0"`). |

### Methods

```dart
static Future<bool> initialize({
  bool enableObjectDetection = true,
  bool enableAR = true,
})
```

Initialises the toolkit. Returns `true` on success. AR is silently disabled
on platforms where it cannot run regardless of `enableAR`.

```dart
static Future<String?> getPlatformVersion()
```

Returns e.g. `"Android 14"` or `"iOS 17.4"`. `null` if the plugin is not
registered on the current platform.

```dart
static bool get isInitialized
```

```dart
static bool isARSupported()
```

Returns `true` on Android and iOS. Does **not** verify the consumer app has
added ARKit/ARCore — AR calls will still fail at runtime if those are
missing.

---

## ImageFilters

All methods are `static` and async. Input/output are `Uint8List` of an
encoded image (JPEG or PNG). The toolkit invokes a native fast-path when
available and falls back to a pure-Dart implementation (via `package:image`)
otherwise — callers don't need to choose.

### Basic filters

| Method | Description |
| --- | --- |
| `applyGrayscale(Uint8List)` | Convert to grayscale. |
| `applyBlur(Uint8List, double sigma)` | Gaussian blur. |
| `applySepia(Uint8List)` | Sepia tone. |
| `applyInvert(Uint8List)` | Invert colours (negative). |
| `adjustBrightness(Uint8List, double factor)` | Brightness delta in `[-1.0, 1.0]`. `0.5` ≈ +50% brighter. |
| `adjustContrast(Uint8List, double contrast)` | Multiplier; `1.0` is neutral. |
| `adjustSaturation(Uint8List, double saturation)` | Multiplier; `1.0` is neutral. |

### Artistic filters

```dart
applyVignette(Uint8List bytes, {double intensity = 0.5, double radius = 0.5})
applyWatercolor(Uint8List bytes, {int radius = 5, double intensity = 0.5})
applyOilPainting(Uint8List bytes, {int radius = 4, int levels = 20})
```

### Geometric transforms

```dart
applyResize(Uint8List bytes, {int? width, int? height})
applyRotate(Uint8List bytes, double angleDegrees)
applyCrop(Uint8List bytes, int x, int y, int width, int height)
applyFlip(Uint8List bytes, {bool horizontal = true, bool vertical = false})
```

`applyResize` maintains aspect ratio if only one dimension is given.

### Watermark

```dart
applyWatermark(
  Uint8List baseBytes,
  Uint8List watermarkBytes, {
  int x = 0,
  int y = 0,
  double opacity = 0.5,
})
```

Composites `watermarkBytes` onto `baseBytes` at `(x, y)`. Opacity is
applied via the watermark's alpha channel — pre-process the watermark image
if you need finer-grained control.

---

## ObjectRecognition

ML Kit-powered detection. **Mobile only** — on the web every method throws
`UnsupportedError`.

```dart
static Future<List<DetectedObject>> detectObjectsFromPath(String imagePath)
```

Recommended entry point. Runs object detection, face detection, pose
estimation, and text recognition on the given file in one call.

```dart
static Future<List<DetectedObject>> detectObjectsFromBytes(
  Uint8List bytes,
  InputImageMetadata metadata,
)
```

Same, but for in-memory bytes. You must provide accurate `InputImageMetadata`
(width, height, rotation, format, `bytesPerRow`) — ML Kit cannot infer
these from the buffer.

```dart
static Future<List<DetectedObject>> detectObjects(String imagePath)
```

Alias for `detectObjectsFromPath` (kept for backwards compatibility).

```dart
static Future<void> dispose()
```

Releases ML Kit detector resources. Call once at app shutdown.

---

## DetectedObject

Immutable result type returned by every `ObjectRecognition` method.

| Property | Type | Description |
| --- | --- | --- |
| `label` | `String` | One of: a detected object category, `"Face"`, `"Text"`, `"Person"`. |
| `confidence` | `double` | `[0.0, 1.0]`. |
| `boundingBox` | `Rect` | Region in source-image pixel coordinates. |
| `additionalData` | `Map<String, dynamic>?` | Detector-specific extras (see below). |

### `additionalData` shape per label

| Label | Keys |
| --- | --- |
| (object) | `trackingId`, `labels` (list of `{text, confidence}`) |
| `"Face"` | `smilingProbability`, `leftEyeOpenProbability`, `rightEyeOpenProbability`, `headEulerAngleY`, `headEulerAngleZ`, `landmarkCount` |
| `"Person"` | `landmarks` (list of `{type, x, y, likelihood}`) |
| `"Text"` | `text`, `lines` (list of `String`) |

### Serialisation

```dart
factory DetectedObject.fromMap(Map<dynamic, dynamic> map)
Map<String, dynamic> toMap()
```

---

## AugmentedReality

Method-channel bindings. The consumer app must add `arkit_plugin` (iOS) or
`arcore_flutter_plugin` (Android) for these to do anything at runtime.

```dart
static bool isARSupported()
static Future<bool> startARSession()
static Future<bool> stopARSession()
static bool get isSessionRunning

static Future<bool> placeModel({
  required String modelPath,
  required List<double> position,  // [x, y, z] in metres, camera-relative
  double scale = 1.0,
  List<double> rotation = const [0.0, 0.0, 0.0],  // degrees
})
```

All methods return `false` (or no-op) and log a warning on web/desktop, or
when the native AR plugin is not wired.

---

## Platform-specific notes

### Android

- AR requires ARCore (`arcore_flutter_plugin`).
- Minimum SDK: 21 (Android 5.0).

### iOS

- AR requires ARKit (`arkit_plugin`).
- Minimum iOS: 12.0 (Google ML Kit requirement).

### Web

- Filters and geometric transforms work via `package:image`.
- `ObjectRecognition` is unavailable — calls throw `UnsupportedError`.
- AR is unavailable — calls return `false`.
