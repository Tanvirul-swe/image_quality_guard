import 'analysis_job.dart';

/// Runs the image quality job on the current isolate.
///
/// Dart web platforms (including Flutter web) have no isolates, so there is no
/// way to move the work off the main isolate. Flutter's own `compute` helper
/// falls back to the main isolate in the same way. The job yields once before
/// it starts so the framework can paint a loading indicator first.
Future<Map<String, dynamic>> invokeImageQualityJob(
  Map<String, dynamic> payload,
) async {
  await Future<void>.delayed(Duration.zero);
  return runImageQualityJob(payload);
}
