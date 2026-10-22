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
    if (width < 3 || height < 3 || luminance.length < width * height) {
      return 0;
    }

    var energySum = 0;
    final count = (width - 2) * (height - 2);

    for (var y = 1; y < height - 1; y++) {
      final topRow = (y - 1) * width;
      final midRow = y * width;
      final botRow = (y + 1) * width;

      for (var x = 1; x < width - 1; x++) {
        final xm1 = x - 1;
        final xp1 = x + 1;

        final topLeft = luminance[topRow + xm1];
        final top = luminance[topRow + x];
        final topRight = luminance[topRow + xp1];

        final left = luminance[midRow + xm1];
        final right = luminance[midRow + xp1];

        final bottomLeft = luminance[botRow + xm1];
        final bottom = luminance[botRow + x];
        final bottomRight = luminance[botRow + xp1];

        final gx = (topRight - topLeft) +
            ((right - left) << 1) +
            (bottomRight - bottomLeft);

        final gy = (bottomLeft - topLeft) +
            ((bottom - top) << 1) +
            (bottomRight - topRight);

        energySum += (gx * gx) + (gy * gy);
      }
    }

    if (count == 0) return 0;

    return math.sqrt(energySum / count);
  }
}
