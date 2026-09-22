/// Platform specific invocation of [invokeImageQualityJob].
///
/// The native implementation runs the job on a background isolate created with
/// `Isolate.run`. On the web, where `dart:isolate` is not available, the job
/// runs on the current isolate after yielding once. Both implementations return
/// the same serializable response map, so the rest of the package does not need
/// to know which one is active.
/// whether the web branch is active.
library;

export 'isolate_runner_web.dart'
    if (dart.library.io) 'isolate_runner_native.dart';
