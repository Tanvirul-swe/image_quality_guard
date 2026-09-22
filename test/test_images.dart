import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Solid single colour RGB image, 16x16 by default.
img.Image solidImage(int luminance, {int width = 16, int height = 16}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(luminance, luminance, luminance));
  return image;
}

/// Black and white checkerboard with the highest possible Laplacian response.
img.Image checkerboardImage({int width = 16, int height = 16}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final luminance = (x + y).isEven ? 0 : 255;
      image.setPixelRgb(x, y, luminance, luminance, luminance);
    }
  }
  return image;
}

/// Vertical light/dark stripes, 32 pixels wide by default.
///
/// Unlike a 1 pixel checkerboard, stripes keep both contrast and edges after
/// area averaged downsampling, which makes this pattern usable for large image
/// tests that must stay in the "acceptable quality" range.
img.Image stripedImage({
  required int width,
  required int height,
  int stripeWidth = 32,
}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final luminance = (x ~/ stripeWidth).isEven ? 20 : 240;
      image.setPixelRgb(x, y, luminance, luminance, luminance);
    }
  }
  return image;
}

/// Encodes [image] as PNG bytes.
Uint8List pngBytes(img.Image image) =>
    Uint8List.fromList(img.encodePng(image));

/// Encodes [image] as JPEG bytes.
Uint8List jpegBytes(img.Image image, {int quality = 85}) =>
    Uint8List.fromList(img.encodeJpg(image, quality: quality));

/// Stripe pattern encoded as PNG bytes.
Uint8List stripedPng({
  required int width,
  required int height,
  int stripeWidth = 32,
}) =>
    pngBytes(
      stripedImage(width: width, height: height, stripeWidth: stripeWidth),
    );
