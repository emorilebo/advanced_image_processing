# Changelog

All notable changes to the Advanced Image Processing Toolkit are documented
in this file.

## [0.3.0] - 2026-11-20

A rebuild of the processing core. Existing `ImageFilters` calls keep their
signatures, but they now run on a new engine that is faster, keeps the
format and transparency you give it, and no longer leaks photo metadata.

### Added

- **`ImagePipeline`**: an immutable, reusable recipe of steps. A run decodes
  once, applies every step on raw pixels, and encodes once. Consecutive
  colour steps are fused into a single pass.
  - Runs on a background isolate (`Isolate.run`) on Android, iOS and
    desktop, so the UI thread never janks. Inline on the web.
  - `runSync` for code already off the main thread, `runAll` for batches
    across several isolates.
  - `toJson` / `ImagePipeline.fromJson` to save and share edit recipes.
  - `custom()` escape hatch for any `package:image` transform.
- **30 operations**: brightness, contrast, saturation, hue, temperature,
  tint, grayscale, sepia, invert, arbitrary colour matrices; exposure (in
  linear light), gamma, levels, posterize, threshold, auto levels, auto
  white balance, auto enhance; Gaussian blur, unsharp-mask sharpen, Sobel
  edges, emboss, pencil sketch; vignette, deterministic film grain,
  pixelate, Kuwahara, oil paint, watercolour; resize (contain / cover /
  fill), downscale, rotate, flip, crop, crop to aspect; region redaction;
  anchored watermarks.
- **`FilterPreset`**: 12 built-in looks (Vivid, Golden Hour, Harmattan,
  Faded Film, Matte, Vintage, Dusk, Arctic, Chrome, Verdant, Mono, Noir).
- **`ColorMatrix`**: composable 4x5 matrices in the same convention as
  Flutter's `ColorFilter.matrix`. `.toColorFilter()` on matrices, presets
  and colour-only pipelines gives a GPU live preview that matches export.
- **`CubeLut`**: parse and apply Adobe/Resolve `.cube` 3D and 1D LUTs, with
  trilinear interpolation and an intensity blend.
- **Privacy**:
  - `ImagePipeline.redact(regions, style: pixelate | blur | fill)`.
  - `ObjectRecognition.redactFromPath()` finds faces (and optionally text)
    with ML Kit and hides them in one call.
  - `MetadataPolicy`: EXIF is stripped by default; `keepWithoutLocation`
    keeps camera data but drops GPS.
  - `maxInputPixels` (default 64 MP) rejects oversized images from the
    header, before any pixel memory is allocated.
- **Widgets**: `ImageCompareSlider` (accessible before/after slider) and
  `DetectionOverlay` (draws detections correctly for any `BoxFit`, plus a
  public `mapRect` helper for hit-testing).
- **Detection**: `detectors:` parameter to run only the ML Kit detectors you
  need (they run concurrently and are created lazily), `detectFaces`,
  `recognizeText`, and a `DetectedObject.type` field.
- `package:advanced_image_processing_toolkit/engine.dart`: the engine
  without any Flutter dependency, for your own isolates, servers and CLIs.
- Typed errors: `ImageProcessingException`, `UnsupportedImageException`,
  `ImageTooLargeException`.
- `tool/benchmark.dart` and `tool/readme_assets/` to reproduce the
  published numbers and images.
- New example app, "Toolkit Studio": live presets and adjustments, render
  with before/after comparison, recipe viewer, export, and on-device
  redaction.

### Changed

- `ImageFilters.*` now keeps the input format: PNG stays PNG (with its
  transparency), JPEG stays JPEG. Formats the engine cannot write (WebP,
  GIF, BMP, TIFF) become PNG if translucent and JPEG otherwise. In 0.2.x
  every result was a JPEG.
- JPEG output defaults to quality 90 (was 100), which makes files several
  times smaller with no visible difference. Use `OutputFormat.jpeg(quality:)`
  to choose.
- Output no longer carries the input's EXIF block (camera, timestamps,
  GPS). In 0.2.x every filter except oil painting copied the original EXIF,
  including the GPS location, into its output.
- `ImageFilters` no longer calls the `advanced_image_processing_toolkit/filters`
  method channel before every operation. Nothing native ever handled it,
  so each call paid a failed platform round trip and a warning log.
- `applyOilPainting` now implements the classic algorithm (the average
  colour of the most common intensity bucket). 0.2.x picked the brightest
  bucket, which behaved like a max filter. It is also about 12x faster in
  `tool/benchmark.dart`.
- `applyVignette` uses a smooth falloff: `radius` is where darkening starts
  and `intensity` is the darkening at the corners.
- `applyBlur` treats its argument as the Gaussian sigma, as documented, and
  costs the same at any radius.
- Face detection finds smaller faces (5% of the image, was 15%) and uses
  ML Kit's accurate mode, which matters for redaction.
- Pose landmark `type` values are the enum name (`leftEye`), not the
  `toString()` form (`PoseLandmarkType.leftEye`).
- ML Kit dependencies accept both the 0.x line and 1.x line (same Dart API),
  so apps on Flutter 3.32 to 3.43 keep resolving 0.x while Flutter 3.44+
  gets 1.x.
- SDK constraints now state the real minimum (Dart 3.8 / Flutter 3.32,
  required by ML Kit). 0.2.0 declared Flutter 3.3 but could not resolve on
  anything below 3.32.
- Web builds pick the web implementations via `dart.library.js_interop`,
  so the package also compiles for WebAssembly.
- Android: compileSdk 36, Java/Kotlin target 17, AGP 8 build script.
- The example app targets iOS 15 and enables Swift Package Manager, which
  the ML Kit 1.x iOS packages require.
- Stricter analysis (`strict-casts`, `strict-inference`, `strict-raw-types`)
  and `flutter_lints` 6.
- The example asset is 2400 px (732 KB) instead of 36 MP (4.7 MB), which
  shrinks the published package.

### Fixed

- `adjustBrightness(bytes, 0.5)` produced a pure white image and any
  negative value produced pure black (the factor was passed to
  `package:image` as a x50 multiplier). It now shifts brightness as
  documented.
- `applyWatermark` ignored `opacity`.
- `applyWatercolor` ignored `intensity`.
- `ObjectRecognition.dispose()` left closed detectors behind, so any later
  detection call failed. Detectors are now recreated on demand.
- `ObjectRecognition` ran its detectors one after another; they now run
  concurrently.
- Blurring a transparent PNG darkened its edges; blur is now
  premultiplied-alpha aware.

### Deprecated

- `AugmentedReality` and `AdvancedImageProcessingToolkit.isARSupported()`.
  The AR channel never had a native implementation, so every call returned
  `false` whatever plugins the app added. They will be removed in 0.4.0.

## [0.2.0] - 2026-05-19

### Breaking

- **Android package renamed** from `com.example.advanced_image_processing_toolkit`
  to `dev.godfreylebo.advanced_image_processing_toolkit`. Consumers do not
  need to change their Dart imports; the change is only visible to Android
  toolchains.
- **`ObjectRecognition.detectObjects`** now takes a file path (`String`)
  instead of `Uint8List`. For raw bytes, use the new
  `detectObjectsFromBytes(bytes, InputImageMetadata)` which requires
  explicit image metadata (ML Kit cannot infer width/height/stride from a
  buffer). The previous bytes-based call would throw at runtime with
  zero-valued metadata; this version fixes that.
- **`ObjectRecognition.drawDetections`** has been removed. It was a stub
  that returned the original bytes unchanged. Draw bounding boxes in your
  own UI layer (e.g. `CustomPainter`).
- **`AR plugins are no longer bundled.`** `arkit_plugin` and
  `arcore_flutter_plugin` were always documented as "optional" but in fact
  pulled into every consumer app. They have been removed from this
  package's dependencies. To use AR, add them to your own app's
  `pubspec.yaml`.

### Changed

- Replaced the umbrella `google_ml_kit` dependency with the individual
  `google_mlkit_*` packages — significant install-size reduction for
  consumer apps. Bumped to the latest 0.11–0.15 series.
- iOS minimum version raised to 12.0 (required by Google ML Kit).
- Android: `compileSdk` → 34, AGP → 7.4.2, Kotlin → 1.9.0, declared
  `namespace` for AGP 7+.
- `dart:io` access guarded behind conditional imports so the package
  compiles cleanly on the web.

### Fixed

- Version numbers were inconsistent across `pubspec.yaml`, the in-library
  `version` constant, the iOS podspec, and `API_REFERENCE.md`. All now read
  `0.2.0`.
- `ObjectRecognition.detectObjects` no longer passes `Size(0, 0)` and
  `bytesPerRow: 0` to `InputImageMetadata` — these would have thrown on
  any real device.
- README documented `detectFaces`, `recognizeText`, `detectPoses`,
  `detectSurfaces`, and named-parameter filter signatures that did not
  exist in the source. The README now matches the actual API surface.
- `API_REFERENCE.md` was stuck on v0.1.2 / v0.0.6 examples and showed
  non-static `final imageFilters = ImageFilters()` usage. Fully rewritten
  against the v0.2.0 API.
- Native `getPlatformVersion` is now implemented on both Android and iOS;
  previously the method handler only had TODO stubs for `applyGrayscale` /
  `applyBlur` and `getPlatformVersion` silently returned `notImplemented`.
- Removed the parallel duplicate platform-interface and method-channel
  files in `lib/src/` that shadowed the canonical ones in `lib/`.

## [0.1.6] - 2025-12-17

### Added

- Geometric transforms: `applyResize`, `applyRotate`, `applyCrop`,
  `applyFlip`.
- Watermarking: `applyWatermark` to overlay images.
- Colour adjustments: `adjustContrast`, `adjustSaturation`.
- Documentation: feature graphic and updated README with new examples.

## [0.1.5] - 2025-09-10

### Changed

- Documentation rewrite with improved structure and tone.
- Updated author information with portfolio link (godfreylebo.dev).
- Better real-world use-case examples in README.
- Updated package description in `pubspec.yaml`.

### Fixed

- Documentation consistency across all files.
- Author metadata alignment.

## [0.1.4] - 2025-06-15

### Changed

- Release with documentation improvements and minor fixes.

## [0.1.3] - 2025-04-20

### Changed

- Documentation updates and improved examples.
- Improved code organisation and structure.

## [0.1.2] - 2025-04-08

### Added

- Improved documentation and examples.
- Enhanced error handling for image processing operations.
- Better platform compatibility checks.

### Fixed

- Documentation inconsistencies.
- Version number alignment across all files.
- Minor performance improvements in filter applications.

## [0.1.1] - 2025-02-15

### Added

- Improved object recognition with ML Kit integration.
- Real face and pose detection.
- Watercolour and oil-painting artistic filters.

### Fixed

- Implementation issues with image filters.
- Null safety issues.
- Documentation updates.

## [0.1.0] - 2025-01-10

### Added

- Initial release with basic filters and object detection.
- Core image processing functionality.
- Preliminary AR support.
- Grayscale, blur, and brightness filters.
- Object detection with confidence scoring.
- AR session management and 3D model placement.
