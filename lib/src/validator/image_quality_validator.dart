import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../config/image_quality_config.dart';
import '../config/quality_config.dart';
import '../detectors/blur_detector.dart';
import '../detectors/brightness_detector.dart';
import '../detectors/contrast_detector.dart';
import '../models/blur_result.dart';
import '../models/brightness_result.dart';
import '../models/contrast_result.dart';
import '../models/image_quality_exception.dart';
import '../models/image_quality_result.dart';
import '../models/quality_result.dart';
import '../processing/image_processor.dart';
import '../processing/isolate_processor.dart';

/// Main validator that combines blur, brightness, and contrast checks.
///
/// Use this class for comprehensive image quality validation with a single
/// entry point. Individual detectors can also be used separately for more
/// granular control.
///
/// [validate] decodes and analyzes the image on a background isolate and is
/// therefore safe to call from a Flutter UI isolate. The image based helpers
/// (`validateFromImage`, `checkBlurFromImage`, ...) run on the calling isolate
/// because they receive an already decoded image.
///
/// Example:
/// ```dart
/// final validator = ImageQualityValidator();
/// final result = await validator.validate(imageBytes);
///
/// if (result.isValid) {
///   // Image quality is acceptable
/// } else {
///   print('Issues: ${result.issues}');
/// }
/// ```
class ImageQualityValidator {
  /// The configuration for quality thresholds.
  final QualityConfig config;

  /// Longest side, in pixels, used while analyzing.
  ///
  /// `0`, the default, analyzes the full resolution and keeps the exact metrics
  /// produced by previous versions of this package. Set it to a smaller value
  /// (for example 1280) to downsample large images before analysis, which is
  /// much faster on camera photos.
  final int maxAnalysisDimension;

  /// Internal blur detector instance.
  late final BlurDetector _blurDetector =
      BlurDetector(threshold: config.blurThreshold);

  /// Internal brightness detector instance.
  late final BrightnessDetector _brightnessDetector = BrightnessDetector(
    minBrightness: config.minBrightness,
    maxBrightness: config.maxBrightness,
  );

  /// Internal contrast detector instance.
  late final ContrastDetector _contrastDetector =
      ContrastDetector(minContrast: config.minContrast);

  /// Creates an [ImageQualityValidator] with the given configuration.
  ///
  /// If no [config] is provided, default thresholds are used.
  ImageQualityValidator({
    this.config = const QualityConfig(),
    this.maxAnalysisDimension = 0,
  });

  /// Analysis settings for the isolate pipeline derived from [config].
  ImageQualityConfig get imageConfig => ImageQualityConfig.fromQualityConfig(
        config,
        maxAnalysisDimension: maxAnalysisDimension,
      );

  /// Validates the image quality from raw bytes.
  ///
  /// Performs all quality checks (blur, brightness, contrast) and returns
  /// a combined [QualityResult].
  ///
  /// Decoding and analysis run on a background isolate, so calling this from a
  /// Flutter UI isolate does not block the event loop. The image is decoded
  /// once and reused by every check.
  ///
  /// Throws an [ArgumentError] if the image cannot be decoded.
  Future<QualityResult> validate(Uint8List imageBytes) async {
    final ImageQualityResult result;
    try {
      result = await _processor.analyze(imageBytes, config: imageConfig);
    } on ImageDecodeException catch (error) {
      // Kept for backwards compatibility: invalid bytes have always been
      // reported as an ArgumentError by this class.
      throw ArgumentError(error.message);
    }
    return _toQualityResult(result);
  }

  /// Validates the quality of an already decoded image.
  ///
  /// Performs all quality checks (blur, brightness, contrast) and returns
  /// a combined [QualityResult]. The [image] is not modified.
  ///
  /// The work runs on the calling isolate, because the decoded image is already
  /// in local memory. Use [validate] with the encoded bytes when the analysis
  /// must not block the UI isolate.
  Future<QualityResult> validateFromImage(img.Image image) async {
    try {
      return _toQualityResult(
        ImageProcessor.processFromImage(image, config: imageConfig),
      );
    } on ImageDecodeException catch (error) {
      throw ArgumentError(error.message);
    }
  }

  /// Checks only the blur of an image from raw bytes.
  ///
  /// Returns a [BlurResult] containing the blur detection result.
  /// Throws an [ArgumentError] if the image cannot be decoded.
  BlurResult checkBlur(Uint8List imageBytes) {
    final prepared = _prepare(imageBytes);
    return _blurDetector.measure(
      prepared.luminance,
      width: prepared.width,
      height: prepared.height,
    );
  }

  /// Checks only the blur of an already decoded image.
  ///
  /// Returns a [BlurResult] containing the blur detection result.
  BlurResult checkBlurFromImage(img.Image image) {
    final prepared = _prepareFromImage(image);
    return _blurDetector.measure(
      prepared.luminance,
      width: prepared.width,
      height: prepared.height,
    );
  }

  /// Checks only the brightness of an image from raw bytes.
  ///
  /// Returns a [BrightnessResult] containing the brightness analysis.
  /// Throws an [ArgumentError] if the image cannot be decoded.
  BrightnessResult checkBrightness(Uint8List imageBytes) =>
      _brightnessDetector.measure(_prepare(imageBytes).luminance);

  /// Checks only the brightness of an already decoded image.
  ///
  /// Returns a [BrightnessResult] containing the brightness analysis.
  BrightnessResult checkBrightnessFromImage(img.Image image) =>
      _brightnessDetector.measure(_prepareFromImage(image).luminance);

  /// Checks only the contrast of an image from raw bytes.
  ///
  /// Returns a [ContrastResult] containing the contrast analysis.
  /// Throws an [ArgumentError] if the image cannot be decoded.
  ContrastResult checkContrast(Uint8List imageBytes) =>
      _contrastDetector.measure(_prepare(imageBytes).luminance);

  /// Checks only the contrast of an already decoded image.
  ///
  /// Returns a [ContrastResult] containing the contrast analysis.
  ContrastResult checkContrastFromImage(img.Image image) =>
      _contrastDetector.measure(_prepareFromImage(image).luminance);

  /// Decodes and prepares [imageBytes], mapping decode failures to the legacy
  /// [ArgumentError] contract of this class.
  PreparedImage _prepare(Uint8List imageBytes) {
    try {
      return ImageProcessor.prepare(
        imageBytes,
        maxAnalysisDimension: maxAnalysisDimension,
      );
    } on ImageDecodeException catch (error) {
      throw ArgumentError(error.message);
    }
  }

  /// Prepares an already decoded [image] for the detectors.
  PreparedImage _prepareFromImage(img.Image image) {
    try {
      return ImageProcessor.prepareFromImage(
        image,
        maxAnalysisDimension: maxAnalysisDimension,
      );
    } on ImageDecodeException catch (error) {
      throw ArgumentError(error.message);
    }
  }

  /// Rebuilds the legacy [QualityResult] from an analyzed [result].
  QualityResult _toQualityResult(ImageQualityResult result) => QualityResult(
        isValid: result.isValid,
        blurResult: _blurDetector.classify(result.blurScore),
        brightnessResult: _brightnessDetector.classify(result.brightness),
        contrastResult: _contrastDetector.classify(result.contrast),
      );
}

/// Shared processor used by every asynchronous validation.
const IsolateProcessor _processor = IsolateProcessor();
