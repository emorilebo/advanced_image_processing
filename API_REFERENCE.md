# API Reference: advanced_image_processing_toolkit

Reference for **v0.3.0**. Everything below is exported from
`package:advanced_image_processing_toolkit/advanced_image_processing_toolkit.dart`.
The Flutter-free engine (`ImagePipeline`, `ColorMatrix`, `CubeLut`,
`FilterPreset`, options and errors) is also available from
`package:advanced_image_processing_toolkit/engine.dart`.

Full dartdoc: <https://pub.dev/documentation/advanced_image_processing_toolkit/latest/>

## Contents

- [ImagePipeline](#imagepipeline)
- [PipelineResult](#pipelineresult)
- [OutputFormat and MetadataPolicy](#outputformat-and-metadatapolicy)
- [Errors](#errors)
- [ColorMatrix](#colormatrix)
- [FilterPreset](#filterpreset)
- [CubeLut](#cubelut)
- [ObjectRecognition](#objectrecognition)
- [DetectedObject, DetectorType, RedactionResult](#detectedobject-detectortype-redactionresult)
- [Widgets and extensions](#widgets-and-extensions)
- [ImageFilters (one-call API)](#imagefilters-one-call-api)
- [AdvancedImageProcessingToolkit](#advancedimageprocessingtoolkit)
- [AugmentedReality (deprecated)](#augmentedreality-deprecated)

---

## ImagePipeline

An immutable recipe. Every builder returns a new pipeline. Arguments are
validated when you build (out-of-range values throw `ArgumentError`).

### Colour (fused into one pass; previewable on the GPU)

| Method | Range / notes |
| --- | --- |
| `brightness(double amount)` | `-1..1`, `0` neutral |
| `contrast(double factor)` | `0..4`, `1` neutral |
| `saturation(double factor)` | `0..4`, `1` neutral, `0` greyscale |
| `hue(double degrees)` | any |
| `grayscale([double amount = 1])` | `0..1` |
| `sepia([double amount = 1])` | `0..1` |
| `invert()` | |
| `temperature(double amount)` | `-1` cool .. `1` warm |
| `tint(double amount)` | `-1` green .. `1` magenta |
| `colorMatrix(ColorMatrix m, {String label})` | any 4x5 matrix |

### Tone

| Method | Notes |
| --- | --- |
| `exposure(double stops)` | `-5..5` EV, computed in linear light |
| `gamma(double gamma)` | `0.1..10`, above `1` lifts mid-tones |
| `levels({int black = 0, int white = 255, double gamma = 1})` | |
| `posterize(int levels)` | `2..256` per channel |
| `threshold([int level = 128])` | black and white on luminance |
| `autoLevels({double clip = 0.005})` | stretch tonal range |
| `autoWhiteBalance({double strength = 1})` | grey-world |
| `autoEnhance()` | `autoLevels()` plus a gentle saturation lift |
| `lut(CubeLut lut, {double intensity = 1})` | `.cube` grade |

### Detail and artistic

| Method | Notes |
| --- | --- |
| `blur(double sigma)` | Gaussian; cost independent of sigma |
| `sharpen({double amount = 0.8, double sigma = 1.2, int threshold = 2})` | unsharp mask |
| `edges({bool invert = false})` | Sobel magnitude |
| `emboss({double strength = 1})` | |
| `sketch({double sigma = 6})` | pencil sketch |
| `vignette({double strength = 0.5, double radius = 0.5})` | `radius` is where falloff starts |
| `grain({double amount = 0.15, int seed = 42})` | deterministic per seed |
| `pixelate(int blockSize)` | whole image |
| `kuwahara({int radius = 4})` | edge-preserving painterly smoothing |
| `oilPaint({int radius = 4, int levels = 20})` | |
| `watercolor({int radius = 5, double intensity = 1})` | |

### Geometry

| Method | Notes |
| --- | --- |
| `resize({int? width, int? height, ResizeFit fit = ResizeFit.contain})` | one side keeps aspect; `contain`, `cover`, `fill` |
| `downscale(int maxSide)` | shrink only; put it first |
| `rotate(double degrees)` | clockwise; right angles are lossless |
| `flip({bool horizontal = true, bool vertical = false})` | |
| `crop(int x, int y, int width, int height)` | clipped to bounds; throws at run time if entirely outside |
| `cropToAspect(double aspectRatio)` | centre crop, e.g. `1`, `4 / 5` |

### Privacy and composition

```dart
ImagePipeline redact(
  Iterable<math.Rectangle<num>> regions, {
  RedactionStyle style = RedactionStyle.pixelate, // pixelate | blur | fill
  double padding = 0.1,   // fraction of each region's size
  int? blockSize,         // default scales with the region
  double? sigma,          // default scales with the region
  int color = 0xFF000000, // ARGB, for fill
})

ImagePipeline watermark(
  Uint8List bytes, {
  WatermarkAnchor anchor = WatermarkAnchor.bottomRight,
  double margin = 0.03,         // fraction of the shorter side
  double opacity = 0.85,
  double? widthFraction = 0.2,  // null keeps the mark's native size
  math.Point<int>? offset,      // exact pixel position; overrides anchor
})
```

### Escape hatch

`custom(String name, img.Image Function(img.Image) transform)` runs any
`package:image` transform. It receives 8-bit RGBA. The function must be
sendable to an isolate (top-level, static, or a closure over sendable
values), and pipelines with custom steps cannot be serialised.

### Composition and inspection

| Member | Description |
| --- | --- |
| `then(ImagePipeline next)` | appends every step of `next` |
| `length`, `isEmpty` | step count |
| `steps` | human-readable step list |
| `previewMatrix` | fused `ColorMatrix` if every step is a colour step, else `null` |
| `isSerializable` | `false` if a `custom` step is present |
| `toJson()` / `ImagePipeline.fromJson(map)` | save and restore recipes |

### Execution

```dart
Future<PipelineResult> run(
  Uint8List input, {
  OutputFormat output = const OutputFormat.original(),
  MetadataPolicy metadata = MetadataPolicy.strip,
  int maxInputPixels = defaultMaxInputPixels, // 64 MP
  bool background = true, // background isolate (ignored on the web)
})

Future<Uint8List> apply(Uint8List input, {OutputFormat output, MetadataPolicy metadata})
PipelineResult runSync(Uint8List input, {OutputFormat output, MetadataPolicy metadata, int maxInputPixels})
Future<List<PipelineResult>> runAll(List<Uint8List> inputs, {..., int concurrency = 2})
```

Photos are always rotated upright from their EXIF orientation. Animated
inputs are processed as their first frame.

---

## PipelineResult

| Field | Type |
| --- | --- |
| `bytes` | `Uint8List` (encoded) |
| `width`, `height` | `int` |
| `format` | `EncodedFormat.jpeg` or `EncodedFormat.png` |
| `processingTime` | `Duration` (decode + steps + encode) |

## OutputFormat and MetadataPolicy

| Constructor | Behaviour |
| --- | --- |
| `OutputFormat.original({int quality = 90, int compression = 6})` | JPEG stays JPEG, PNG stays PNG; other inputs become PNG if translucent, else JPEG |
| `OutputFormat.jpeg({int quality = 90, int background = 0xFFFFFFFF})` | transparency flattened onto `background` |
| `OutputFormat.png({int compression = 6})` | opaque images are written without an alpha channel |

`MetadataPolicy.strip` (default), `.keepWithoutLocation` (drops GPS),
`.keep` (everything except orientation).

## Errors

| Type | When |
| --- | --- |
| `ImageProcessingException` | base class; also e.g. a crop entirely outside the image |
| `UnsupportedImageException` | input or watermark bytes are not a decodable image |
| `ImageTooLargeException` | header declares more than `maxInputPixels` (has `width`, `height`, `maxPixels`) |

---

## ColorMatrix

A 4x5 row-major matrix whose offset column is in `0..255`, exactly like
Flutter's `ColorFilter.matrix`.

| Member | Description |
| --- | --- |
| `ColorMatrix(List<double> values)` | 20 values |
| `ColorMatrix.identity` | |
| `.brightness`, `.contrast`, `.saturation`, `.hueRotate`, `.grayscale`, `.sepia`, `.invert`, `.temperature`, `.tint`, `.channelGains` | factories |
| `then(ColorMatrix next)` | apply this, then `next` |
| `withStrength(double t)`, `ColorMatrix.lerp(a, b, t)` | blend towards identity / between matrices |
| `values` | pass to `ColorFilter.matrix` |
| `applyToRgba(Uint8List rgba)` | in-place on raw RGBA8888 |
| `toJson()` / `ColorMatrix.fromJson(list)` | |

## FilterPreset

`FilterPreset.all` (12 presets): `vivid`, `goldenHour`, `harmattan`,
`fadedFilm`, `matte`, `vintage`, `dusk`, `arctic`, `chrome`, `verdant`,
`mono`, `noir`. Each has `id`, `name`, `matrix`, `vignette`, `grain`,
`pipeline` and `apply(bytes)`. `FilterPreset.byId(id)` looks one up.

## CubeLut

| Member | Description |
| --- | --- |
| `CubeLut.parse(String source)` | `.cube` text; throws `FormatException` when malformed |
| `CubeLut.identity({int size = 17})` | |
| `size`, `is3d`, `title`, `domainMin`, `domainMax` | |
| `applyToRgba(Uint8List rgba, {double intensity = 1})` | in place |
| `toJson()` / `CubeLut.fromJson(map)` | |

---

## ObjectRecognition

Google ML Kit, Android and iOS only (the web build throws
`UnsupportedError`).

```dart
static Future<List<DetectedObject>> detectObjectsFromPath(String path, {Set<DetectorType> detectors = DetectorType.all})
static Future<List<DetectedObject>> detectObjectsFromBytes(Uint8List bytes, InputImageMetadata metadata, {Set<DetectorType> detectors})
static Future<List<DetectedObject>> detectObjects(String path, {Set<DetectorType> detectors}) // alias
static Future<List<DetectedObject>> detectFaces(String path)
static Future<List<DetectedObject>> recognizeText(String path)
static Future<RedactionResult> redactFromPath(
  String path, {
  Set<DetectorType> targets = const {DetectorType.face},
  RedactionStyle style = RedactionStyle.pixelate,
  double padding = 0.15,
  OutputFormat output = const OutputFormat.original(),
  MetadataPolicy metadata = MetadataPolicy.strip,
})
static Future<void> dispose()
```

A detector that fails (for example while its model downloads) is logged and
contributes no results; the others still run.

## DetectedObject, DetectorType, RedactionResult

`DetectorType`: `object`, `face`, `pose`, `text`, and `DetectorType.all`.

`DetectedObject`: `label`, `confidence` (`1.0` for faces and text, which ML
Kit does not score; mean landmark likelihood for pose), `boundingBox`
(`Rect`, upright image pixels), `additionalData`, `type`, `region`
(`math.Rectangle` for `redact`), `toMap()` / `fromMap()`.

`RedactionResult`: `bytes`, `width`, `height`, `regions`.

`Rect.toRectangle()` converts a Flutter `Rect` for `ImagePipeline.redact`.

---

## Widgets and extensions

- `ImageCompareSlider({before, after, initialPosition = 0.5, axis, dividerColor, dividerThickness, handleSize, beforeLabel, afterLabel, onChanged, semanticLabel})`
- `DetectionOverlay({imageSize, detections, child, fit = BoxFit.contain, alignment, strokeWidth, showLabels, colorFor, labelFor, labelStyle})`
  and `DetectionOverlay.mapRect(box, imageSize:, widgetSize:, fit:, alignment:)`
- `ColorMatrix.toColorFilter()`, `FilterPreset.toColorFilter()`,
  `ImagePipeline.toColorFilter()` (`null` if not colour-only)

---

## ImageFilters (one-call API)

Static, `Future<Uint8List>`, kept from 0.2.x. Each call is a one-step
pipeline (background isolate, format kept, metadata stripped). Undecodable
input is logged and returned unchanged, as in 0.2.x.

`applyGrayscale`, `applyBlur(bytes, sigma)`, `adjustBrightness(bytes, -1..1)`,
`applySepia`, `applyInvert`, `applyVignette({intensity, radius})`,
`applyWatercolor({radius, intensity})`, `applyOilPainting({radius, levels})`,
`applyResize({width, height})` (both sides: exact stretch), `applyRotate`,
`applyCrop(bytes, x, y, width, height)`, `applyFlip({horizontal, vertical})`,
`adjustContrast`, `adjustSaturation`,
`applyWatermark(base, mark, {x, y, opacity})`.

## AdvancedImageProcessingToolkit

`version`, `initialize()` (optional), `isInitialized`,
`getPlatformVersion()`, `isDetectionSupported`, `runsInBackground`.

## AugmentedReality (deprecated)

Never had a native implementation; every call returns `false`. Removed in
0.4.0.
