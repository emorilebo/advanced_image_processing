// Runs CPU-heavy work off the calling isolate where the platform allows it.
//
// Native platforms use `Isolate.run`, so pixel work never blocks the UI
// thread. The web has no shared-memory isolates, so work runs inline there.
export 'runner_io.dart' if (dart.library.js_interop) 'runner_web.dart';
