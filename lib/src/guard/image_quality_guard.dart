import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../config/image_quality_config.dart';
import '../models/image_quality_result.dart';
import '../processing/isolate_processor.dart';

/// One-call entry point for image quality analysis.
///
/// All CPU intensive work - decoding, downsampling, grayscale conversion, blur,
/// brightness and contrast analysis - runs on a background isolate, so the
/// Flutter UI keeps rendering and never drops a frame while a large camera photo
/// is analyzed:
///
/// ```text
/// Flutter UI
///     -> ImageQualityGuard.analyze()
///     -> background isolate
///     -> decode -> optional downsampling -> analysis
///     -> serializable result -> ImageQualityResult
/// ```
///
/// ```dart
/// try {
///   final result = await ImageQualityGuard.analyze(imageBytes);
///
///   if (result.isValid) {
///     upload(imageBytes);
///   } else {
///     showHint(result.issues.first);
///   }
/// } on ImageQualityException catch (error) {
///   showError(error.message);
/// }
/// ```
class ImageQualityGuard {
  const ImageQualityGuard._();

  /// Shared processor instance; it is stateless and safe to reuse.
  static const IsolateProcessor _processor = IsolateProcessor();

  /// Analyzes [imageBytes] on a background isolate.
  ///
  /// The image is decoded once and reused for every detector. Images whose
  /// longest side exceeds `config.maxAnalysisDimension` are downsampled first
  /// while the aspect ratio is preserved; smaller images are never upscaled.
  ///
  /// Throws an [ImageDecodeException] for invalid, unsupported or corrupted
  /// bytes, an [ImageAnalysisException] for unexpected analysis errors and an
  /// [ImageIsolateException] when the background isolate cannot be used. All of
  /// them extend `ImageQualityException`.
  static Future<ImageQualityResult> analyze(
    Uint8List imageBytes, {
    ImageQualityConfig config = const ImageQualityConfig(),
  }) =>
      _processor.analyze(imageBytes, config: config);

  /// Analyzes [imageBytes] on the calling isolate.
  ///
  /// Provided for tests and for callers that already own a background execution
  /// context. On a Flutter UI isolate this blocks the event loop for the whole
  /// duration of the analysis; prefer [analyze].
  static ImageQualityResult analyzeSync(
    Uint8List imageBytes, {
    ImageQualityConfig config = const ImageQualityConfig(),
  }) =>
      _processor.analyzeSync(imageBytes, config: config);

  /// Analyzes an image that was already decoded with `package:image`.
  ///
  /// Runs on the calling isolate, because handing a decoded image to another
  /// isolate costs at least as much as re-analyzing the encoded bytes. Prefer
  /// [analyze] whenever the encoded bytes are still available.
  static ImageQualityResult analyzeImageSync(
    img.Image image, {
    ImageQualityConfig config = const ImageQualityConfig(),
  }) =>
      _processor.analyzeImageSync(image, config: config);
}
