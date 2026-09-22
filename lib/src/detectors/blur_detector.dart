import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/blur_result.dart';
import '../processing/luminance_extractor.dart';
import '../processing/luminance_statistics.dart';

/// Detects blur in images using the Laplacian variance method.
///
/// The Laplacian variance method works by applying a Laplacian filter
/// to detect edges in the image, then calculating the variance of the
/// result. Sharp images have high variance (many strong edges), while
/// blurry images have low variance (edges are smoothed out).
///
/// The calculation itself only needs a flat luminance buffer, which is why
/// [measure] and [laplacianVariance] can run inside the background processing
/// isolate without any `package:image` object.
class BlurDetector {
  /// The threshold below which an image is considered blurry.
  /// Higher values require sharper images.
  final double threshold;

  /// Creates a [BlurDetector] with the given threshold.
  ///
  /// The [threshold] determines the sensitivity of blur detection.
  /// Typical values range from 50 to 500, with 100 being a good default.
  const BlurDetector({this.threshold = 100.0})
      : assert(threshold > 0, 'threshold must be positive');

  /// Detects blur in an image from raw bytes.
  ///
  /// Decoding happens on the calling isolate; prefer `ImageQualityGuard.analyze`
  /// when the image is large, because that entry point decodes and analyzes the
  /// image on a background isolate.
  ///
  /// Returns a [BlurResult] containing the blur detection result.
  /// Throws an [ArgumentError] if the image cannot be decoded.
  BlurResult detect(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw ArgumentError('Cannot decode image from provided bytes');
    }
    return detectFromImage(image);
  }

  /// Detects blur in an already decoded image.
  ///
  /// The image is not modified. Returns a [BlurResult] containing the blur
  /// detection result.
  BlurResult detectFromImage(img.Image image) => measure(
        LuminanceExtractor.fromImage(image),
        width: image.width,
        height: image.height,
      );

  /// Detects blur from a flat luminance buffer.
  ///
  /// [luminance] holds one sample per pixel, row major, and must describe a
  /// [width] x [height] image.
  BlurResult measure(
    Uint8List luminance, {
    required int width,
    required int height,
  }) =>
      classify(laplacianVariance(luminance, width: width, height: height));

  /// Classifies an already calculated Laplacian [variance].
  ///
  /// Useful when the variance was produced by the processing isolate: the
  /// statistic is a plain [double], so the result object can be rebuilt on the
  /// main isolate without touching pixels again.
  BlurResult classify(double variance) => BlurResult(
        isBlurry: variance < threshold,
        variance: variance,
        confidence: _calculateConfidence(variance),
        threshold: threshold,
      );

  /// Calculates the variance of the Laplacian response of [luminance].
  ///
  /// The 4-neighbour Laplacian (`4 * center - up - down - left - right`) is
  /// evaluated per pixel and folded into a running variance with Welford's
  /// algorithm. No per-pixel list of Laplacian values is materialised, so the
  /// peak memory of the blur detector is the luminance buffer itself.
  ///
  /// Border pixels are skipped because their neighbourhood is incomplete.
  static double laplacianVariance(
    Uint8List luminance, {
    required int width,
    required int height,
  }) {
    if (width < 3 || height < 3 || luminance.length < width * height) {
      // Not enough pixels left after skipping the border.
      return 0;
    }

    final statistics = RunningStatistics();
    for (var y = 1; y < height - 1; y++) {
      final rowStart = y * width;
      for (var x = 1; x < width - 1; x++) {
        final index = rowStart + x;
        final response = 4.0 * luminance[index] -
            luminance[index - 1] -
            luminance[index + 1] -
            luminance[index - width] -
            luminance[index + width];
        statistics.add(response);
      }
    }

    return statistics.variance;
  }

  /// Calculates confidence based on distance from threshold.
  double _calculateConfidence(double variance) {
    // Map variance to confidence (0.0 - 1.0)
    // Far from threshold = high confidence
    // Close to threshold = low confidence
    final distance = (variance - threshold).abs();
    final maxDistance = threshold * 2;

    // Use sigmoid-like function for smooth confidence curve
    final normalized = math.min(distance / maxDistance, 1.0);
    return 0.5 + (normalized * 0.5);
  }
}
