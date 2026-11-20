/// Whether [runInBackground] actually leaves the calling isolate.
const bool supportsBackgroundIsolates = false;

/// Runs [task] inline. The web platform has no background isolates that can
/// share Dart objects, so heavy pipelines should downscale first.
Future<R> runInBackground<R>(R Function() task) async => task();
