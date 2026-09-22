import 'dart:typed_data';

import '../models/brightness_level.dart';
import '../models/brightness_result.dart';
import '../processing/luminance_statistics.dart';

/// Measures and classifies brightness from a flat luminance buffer.
///
/// The detector works on isolate-safe [Uint8List] samples instead of
/// `package:image` objects, which lets the background processing isolate reuse
/// exactly the same code as the image based analyzers.
class BrightnessDetector {
  /// Minimum acceptable brightness value (0-255 scale).
  final double minBrightness;

  /// Maximum acceptable brightness value (0-255 scale).
  final double maxBrightness;

  /// Creates a [BrightnessDetector] with the given thresholds.
  const BrightnessDetector({
    this.minBrightness = 40.0,
    this.maxBrightness = 220.0,
  })  : assert(minBrightness >= 0 && minBrightness <= 255,
            'minBrightness must be between 0 and 255'),
        assert(maxBrightness >= 0 && maxBrightness <= 255,
            'maxBrightness must be between 0 and 255'),
        assert(minBrightness < maxBrightness,
            'minBrightness must be less than maxBrightness');

  /// Average luminance of [luminance] on a 0-255 scale.
  ///
  /// The mean is calculated with an incremental algorithm, so no per-pixel list
  /// is allocated.
  static double averageOf(Uint8List luminance) =>
      summarizeLuminance(luminance).mean;

  /// Measures [luminance] and classifies the result.
  BrightnessResult measure(Uint8List luminance) =>
      classify(averageOf(luminance));

  /// Classifies an already measured average [brightness].
  BrightnessResult classify(double brightness) {
    final BrightnessLevel level = brightness < minBrightness
        ? BrightnessLevel.tooDark
        : brightness > maxBrightness
            ? BrightnessLevel.tooBright
            : BrightnessLevel.optimal;

    return BrightnessResult(
      level: level,
      averageBrightness: brightness,
      minThreshold: minBrightness,
      maxThreshold: maxBrightness,
    );
  }
}
