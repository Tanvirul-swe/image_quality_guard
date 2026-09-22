import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/image_quality_exception.dart';

/// Converts decoded `image` package objects into flat 8-bit luminance buffers.
///
/// The buffer is a plain [Uint8List] with one sample per pixel, row major. It
/// is the only pixel representation that is passed around inside the package:
/// it can be sent to a background isolate, it cannot hold a reference to a
/// `package:image` object and it needs four times less memory than a list of
/// doubles.
abstract final class LuminanceExtractor {
  /// Returns a single frame, uint8 backed version of [image].
  ///
  /// Palette images and high dynamic range images (16 bit or floating point
  /// samples) are normalized so that [fromImage] can read raw samples. Images
  /// that already have an addressable uint8 buffer are returned unchanged, so
  /// this call is allocation free for the common JPEG/PNG case.
  static img.Image normalize(img.Image image) {
    var source = image;
    if (source.data == null) {
      // Some multi frame containers keep the pixels in their frames instead of
      // the root image; flatten the first frame so pixel data is addressable.
      source = img.Image.from(source, noAnimation: true);
    }
    if (source.data == null) {
      throw const ImageDecodeException(
        message: 'Decoded image does not contain pixel data',
      );
    }
    if (source.hasPalette || source.format != img.Format.uint8) {
      source = source.convert(
        format: img.Format.uint8,
        numChannels: source.numChannels,
      );
    }
    return source;
  }

  /// Extracts one luminance sample per pixel from [image].
  ///
  /// Grayscale conversion happens here in a single pass: every pixel is
  /// weighted with the Rec. 601 luma formula used by `package:image`
  /// (`0.299 R + 0.587 G + 0.114 B`), which keeps the values comparable with the
  /// individual detectors of this package.
  static Uint8List fromImage(img.Image image) {
    final source = normalize(image);
    final width = source.width;
    final height = source.height;
    final samples = Uint8List(width * height);
    var index = 0;
    // Iterating a package:image image reuses a single pixel view, so this loop
    // performs no allocation per pixel.
    for (final pixel in source) {
      samples[index++] = _luma(pixel);
    }
    return samples;
  }

  /// Rec. 601 luma of a single [pixel], quantized to the 0-255 range.
  static int _luma(img.Pixel pixel) =>
      (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b).round().clamp(0, 255);
}
