import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../config/image_quality_config.dart';
import '../models/image_quality_exception.dart';
import '../models/image_quality_result.dart';
import 'analysis_job.dart';
import 'image_processor.dart';
import 'isolate_runner.dart';

/// Executes the CPU intensive image quality pipeline outside the main isolate.
///
/// The processor hides every isolate detail: each call builds a serializable
/// payload, runs the job on a short lived background isolate (see
/// [invokeImageQualityJob]) and rebuilds the result model on the calling
/// isolate.
///
/// ```dart
/// const processor = IsolateProcessor();
/// final result = await processor.analyze(imageBytes);
/// ```
///
/// Prefer `ImageQualityGuard.analyze` in application code; this class exists for
/// callers that want to own the processor, for example to reuse it across
/// screens or to inject it in tests.
class IsolateProcessor {
  /// Creates a stateless processor.
  const IsolateProcessor();

  /// Analyzes [imageBytes] on a background isolate.
  ///
  /// Throws an [ImageDecodeException] when the bytes are not a usable image, an
  /// [ImageAnalysisException] when the analysis fails and an
  /// [ImageIsolateException] when the background isolate cannot be used. The
  /// application is never left with an uncaught isolate error.
  Future<ImageQualityResult> analyze(
    Uint8List imageBytes, {
    ImageQualityConfig config = const ImageQualityConfig(),
  }) async {
    final payload = buildImageQualityPayload(imageBytes, config);

    final Map<String, dynamic> response;
    try {
      response = await invokeImageQualityJob(payload);
    } on Object catch (error, stackTrace) {
      // The job reports its own failures through the response map, so anything
      // thrown here is an isolate level failure (spawn refused, isolate
      // terminated, result not transferable, ...).
      throw ImageIsolateException(
        cause: '$error\n$stackTrace',
      );
    }

    return decodeImageQualityResponse(response);
  }

  /// Analyzes [imageBytes] on the calling isolate.
  ///
  /// Only useful for tests, command line tools or callers that already manage
  /// their own background execution. On a Flutter UI isolate this blocks the
  /// event loop for the whole duration of the analysis.
  ImageQualityResult analyzeSync(
    Uint8List imageBytes, {
    ImageQualityConfig config = const ImageQualityConfig(),
  }) =>
      ImageProcessor.processBytes(imageBytes, config: config);

  /// Analyzes an image that was already decoded with `package:image`.
  ///
  /// The work runs on the calling isolate: a decoded image cannot be handed to
  /// a background isolate as cheaply as its encoded bytes. Prefer [analyze] with
  /// the original bytes when responsiveness matters.
  ImageQualityResult analyzeImageSync(
    img.Image image, {
    ImageQualityConfig config = const ImageQualityConfig(),
  }) =>
      ImageProcessor.processFromImage(image, config: config);
}
