/// A Flutter/Dart package to detect blur, brightness, and contrast issues
/// in images with configurable thresholds.
///
/// This package provides tools for validating image quality before processing,
/// which is especially useful for card scanning, document scanning, and
/// photo capture scenarios.
///
/// ## Quick Start (background isolate)
///
/// ```dart
/// import 'package:image_quality_guard/image_quality_guard.dart';
///
/// // Decoding, downsampling and every quality metric run on a background
/// // isolate, so the UI keeps rendering while a large photo is analyzed.
/// final result = await ImageQualityGuard.analyze(imageBytes);
///
/// if (result.isValid) {
///   // Proceed with image processing
/// } else {
///   print('Issues: ${result.issues}');
/// }
/// ```
///
/// ## Large images
///
/// Images larger than `maxAnalysisDimension` (1280 pixels by default) are
/// downsampled before analysis while the aspect ratio is preserved. Smaller
/// images are never upscaled.
///
/// ```dart
/// final result = await ImageQualityGuard.analyze(
///   imageBytes,
///   config: const ImageQualityConfig(maxAnalysisDimension: 1280),
/// );
///
/// print('${result.originalWidth}x${result.originalHeight} -> '
///     '${result.analyzedWidth}x${result.analyzedHeight} '
///     'in ${result.processingTimeMs} ms');
/// ```
///
/// ## Validator API
///
/// [ImageQualityValidator] keeps its original result shape and now also analyzes
/// bytes on a background isolate:
///
/// ```dart
/// final validator = ImageQualityValidator(
///   config: ImageQualityConfig.cardScanning,
/// );
/// final result = await validator.validate(imageBytes);
/// ```
///
/// ## Presets
///
/// ```dart
/// final guardResult = await ImageQualityGuard.analyze(
///   imageBytes,
///   config: ImageQualityConfig.photoCapture,
/// );
/// ```
library;

// Config
export 'src/config/image_quality_config.dart';
export 'src/config/quality_config.dart';

// Detectors
export 'src/detectors/blur_detector.dart';
export 'src/detectors/brightness_analyzer.dart';
export 'src/detectors/brightness_detector.dart';
export 'src/detectors/contrast_analyzer.dart';
export 'src/detectors/contrast_detector.dart';

// Guard
export 'src/guard/image_quality_guard.dart';

// Models
export 'src/models/blur_result.dart';
export 'src/models/brightness_level.dart';
export 'src/models/brightness_result.dart';
export 'src/models/contrast_result.dart';
export 'src/models/image_quality_exception.dart';
export 'src/models/image_quality_result.dart';
export 'src/models/quality_result.dart';

// Validator
export 'src/validator/image_quality_validator.dart';
