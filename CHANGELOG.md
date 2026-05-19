# Changelog

All notable changes to the Advanced Image Processing Toolkit are documented
in this file.

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
