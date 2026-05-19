// Platform-detection shim that avoids importing `dart:io` on the web.
//
// Web builds cannot resolve `dart:io` at compile time. Conditional imports
// pick the right implementation per platform so `kIsWeb`/`Platform.is*`
// guards work without breaking the web target.

export 'platform_support_io.dart' if (dart.library.html) 'platform_support_web.dart';
