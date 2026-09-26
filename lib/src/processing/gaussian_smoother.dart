import 'dart:typed_data';

/// Small 3x3 Gaussian smoothing used before sharpness detection.
///
/// Kernel:
///
/// 1 2 1
/// 2 4 2
/// 1 2 1
///
/// Divisor = 16
///
/// This removes sensor noise, JPEG artifacts, and single-pixel noise that can
/// incorrectly increase Laplacian variance.
abstract final class GaussianSmoother {
  static Uint8List apply3x3(
    Uint8List input, {
    required int width,
    required int height,
  }) {
    if (width < 3 || height < 3 || input.length < width * height) {
      return Uint8List.fromList(input);
    }

    final output = Uint8List(input.length);

    // Copy top and bottom borders.
    for (var x = 0; x < width; x++) {
      output[x] = input[x];

      final bottomIndex = (height - 1) * width + x;
      output[bottomIndex] = input[bottomIndex];
    }

    // Copy left and right borders.
    for (var y = 0; y < height; y++) {
      final leftIndex = y * width;
      final rightIndex = leftIndex + width - 1;

      output[leftIndex] = input[leftIndex];
      output[rightIndex] = input[rightIndex];
    }

    for (var y = 1; y < height - 1; y++) {
      final row = y * width;

      for (var x = 1; x < width - 1; x++) {
        final index = row + x;

        final sum = input[index - width - 1] +
            (2 * input[index - width]) +
            input[index - width + 1] +
            (2 * input[index - 1]) +
            (4 * input[index]) +
            (2 * input[index + 1]) +
            input[index + width - 1] +
            (2 * input[index + width]) +
            input[index + width + 1];

        // +8 for integer rounding before /16.
        output[index] = (sum + 8) >> 4;
      }
    }

    return output;
  }
}
