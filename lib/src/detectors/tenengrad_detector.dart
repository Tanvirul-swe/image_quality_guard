import 'dart:math' as math;
import 'dart:typed_data';

/// Measures sharpness using Sobel gradients.
///
/// The returned value is the RMS gradient magnitude.
///
/// Higher score = stronger edges / more image detail.
abstract final class TenengradDetector {
  static double score(
    Uint8List luminance, {
    required int width,
    required int height,
  }) {
    if (width < 3 ||
        height < 3 ||
        luminance.length < width * height) {
      return 0;
    }

    double energySum = 0;
    var count = 0;

    for (var y = 1; y < height - 1; y++) {
      final row = y * width;

      for (var x = 1; x < width - 1; x++) {
        final i = row + x;

        final topLeft = luminance[i - width - 1];
        final top = luminance[i - width];
        final topRight = luminance[i - width + 1];

        final left = luminance[i - 1];
        final right = luminance[i + 1];

        final bottomLeft = luminance[i + width - 1];
        final bottom = luminance[i + width];
        final bottomRight = luminance[i + width + 1];

        final gx =
            -topLeft +
            topRight -
            (2 * left) +
            (2 * right) -
            bottomLeft +
            bottomRight;

        final gy =
            -topLeft -
            (2 * top) -
            topRight +
            bottomLeft +
            (2 * bottom) +
            bottomRight;

        energySum += (gx * gx) + (gy * gy);
        count++;
      }
    }

    if (count == 0) return 0;

    return math.sqrt(energySum / count);
  }
}