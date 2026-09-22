import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/blur_result.dart';

/// Detects blur in images using the Laplacian variance method.
///
/// The Laplacian variance method works by applying a Laplacian filter
/// to detect edges in the image, then calculating the variance of the
/// result. Sharp images have high variance (many strong edges), while
/// blurry images have low variance (edges are smoothed out).
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
  /// Returns a [BlurResult] containing the blur detection result.
  BlurResult detectFromImage(img.Image image) {
    // Convert to grayscale for edge detection
    final grayscale = img.grayscale(image);

    final variance = _calculateLaplacianVariance(grayscale);

    // Calculate confidence based on how far the variance is from threshold
    final confidence = _calculateConfidence(variance);

    return BlurResult(
      isBlurry: variance < threshold,
      variance: variance,
      confidence: confidence,
      threshold: threshold,
    );
  }

  /// Calculates Laplacian variance without retaining a value per pixel.
  double _calculateLaplacianVariance(img.Image grayscale) {
    final width = grayscale.width;
    final height = grayscale.height;
    const kernel = [0, 1, 0, 1, -4, 1, 0, 1, 0];
    var count = 0;
    var mean = 0.0;
    var sumSquaredDifference = 0.0;

    for (var y = 1; y < height - 1; y++) {
      for (var x = 1; x < width - 1; x++) {
        var sum = 0.0;
        var kernelIndex = 0;

        for (var ky = -1; ky <= 1; ky++) {
          for (var kx = -1; kx <= 1; kx++) {
            final pixel = grayscale.getPixel(x + kx, y + ky);
            final luminance = img.getLuminance(pixel);
            sum += luminance * kernel[kernelIndex];
            kernelIndex++;
          }
        }

        count++;
        final difference = sum - mean;
        mean += difference / count;
        final adjustedDifference = sum - mean;
        sumSquaredDifference += difference * adjustedDifference;
      }
    }

    return count == 0 ? 0 : sumSquaredDifference / count;
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
