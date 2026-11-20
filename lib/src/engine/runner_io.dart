import 'dart:isolate';

/// Whether [runInBackground] actually leaves the calling isolate.
const bool supportsBackgroundIsolates = true;

/// Runs [task] on a short-lived background isolate.
///
/// The result is returned with `Isolate.exit`, so large byte buffers come
/// back without a copy.
Future<R> runInBackground<R>(R Function() task) => Isolate.run(task);
