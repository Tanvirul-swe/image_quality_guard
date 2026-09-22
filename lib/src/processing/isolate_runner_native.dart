import 'dart:isolate';

import 'analysis_job.dart';

/// Runs the image quality job on a background isolate.
///
/// [Isolate.run] spawns a short lived isolate, executes the closure with a
/// copy of [payload] and shuts the isolate down as soon as the job responds.
/// Callers never create, keep or dispose isolates themselves.
///
/// This implementation is used on every platform that has `dart:isolate`
/// (Android, iOS, macOS, Windows, Linux and Dart native).
Future<Map<String, dynamic>> invokeImageQualityJob(
  Map<String, dynamic> payload,
) =>
    Isolate.run(() => runImageQualityJob(payload));
