import 'dart:typed_data';

import '../models/contrast_result.dart';
import '../processing/luminance_statistics.dart';

/// Measures and classifies contrast from a flat luminance buffer.
///
/// Contrast is the population standard deviation of the luminance samples: a
/// flat image (all pixels equal) has a score of zero, while an image with a wide
/// tonal range has a high score. The statistics are accumulated incrementally,
/// so the detector never materialises a list with one entry per pixel.
class ContrastDetector {
  /// Minimum acceptable contrast score (standard deviation of luminance).
  final double minContrast;

  /// Creates a [ContrastDetector] with the given threshold.
  const ContrastDetector({this.minContrast = 50.0})
      : assert(minContrast >= 0, 'minContrast must be non-negative');

  /// Population standard deviation of [luminance].
  static double standardDeviationOf(Uint8List luminance) =>
      summarizeLuminance(luminance).standardDeviation;

  /// Measures [luminance] and classifies the result.
  ContrastResult measure(Uint8List luminance) =>
      classify(standardDeviationOf(luminance));

  /// Classifies an already measured [contrastScore].
  ContrastResult classify(double contrastScore) => ContrastResult(
        hasGoodContrast: contrastScore >= minContrast,
        contrastScore: contrastScore,
        threshold: minContrast,
      );
}
