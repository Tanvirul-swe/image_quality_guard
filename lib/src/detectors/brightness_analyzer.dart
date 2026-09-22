import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/brightness_result.dart';
import '../processing/luminance_extractor.dart';
import 'brightness_detector.dart';

/// Analyzes image brightness to detect underexposed or overexposed images.
///
/// Uses luminance calculation to determine the average brightness of an image
/// and classifies it as too dark, optimal, or too bright based on configured
/// thresholds.
///
/// The actual measurement is implemented by [BrightnessDetector], which also
/// runs inside the background processing isolate of
/// `ImageQualityGuard.analyze`.
class BrightnessAnalyzer {
  /// Minimum acceptable brightness value (0-255 scale).
  /// Images below this value are considered too dark.
  final double minBrightness;

  /// Maximum acceptable brightness value (0-255 scale).
  /// Images above this value are considered too bright.
  final double maxBrightness;

  /// Creates a [BrightnessAnalyzer] with the given thresholds.
  ///
  /// The [minBrightness] and [maxBrightness] values should be between 0 and 255.
  /// Default values are 40.0 and 220.0 respectively.
  const BrightnessAnalyzer({
    this.minBrightness = 40.0,
    this.maxBrightness = 220.0,
  })  : assert(minBrightness >= 0 && minBrightness <= 255,
            'minBrightness must be between 0 and 255'),
        assert(maxBrightness >= 0 && maxBrightness <= 255,
            'maxBrightness must be between 0 and 255'),
        assert(minBrightness < maxBrightness,
            'minBrightness must be less than maxBrightness');

  /// Analyzes brightness of an image from raw bytes.
  ///
  /// Decoding happens on the calling isolate. Returns a [BrightnessResult]
  /// containing the brightness analysis.
  /// Throws an [ArgumentError] if the image cannot be decoded.
  BrightnessResult analyze(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw ArgumentError('Cannot decode image from provided bytes');
    }
    return analyzeFromImage(image);
  }

  /// Analyzes brightness of an already decoded image.
  ///
  /// The image is not modified. Returns a [BrightnessResult] containing the
  /// brightness analysis.
  BrightnessResult analyzeFromImage(img.Image image) => classify(
        BrightnessDetector.averageOf(LuminanceExtractor.fromImage(image)),
      );

  /// Classifies an already measured average [averageBrightness].
  BrightnessResult classify(double averageBrightness) => BrightnessDetector(
        minBrightness: minBrightness,
        maxBrightness: maxBrightness,
      ).classify(averageBrightness);
}

