import 'dart:math' as math;
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
Uint8List pngBytes(img.Image image) => Uint8List.fromList(img.encodePng(image));

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

/// Phone-style photo of an ID card lying on a table, 1600x1200 by default.
///
/// Like a real card capture, only the text lines carry fine detail: the table,
/// the plain card surface and the portrait are smooth even when the photo is
/// perfectly focused. Pass a [blurRadius] to simulate an out of focus capture.
img.Image cardPhotoImage({
  int width = 1600,
  int height = 1200,
  int blurRadius = 0,
}) {
  final image = img.Image(width: width, height: height);
  // Table with a gentle gradient and low frequency grain.
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final value = (110 + 30 * math.sin(y / 36.0) + y / 24).round();
      final luminance = value.clamp(0, 255);
      image.setPixelRgb(
          x, y, luminance, luminance * 4 ~/ 5, luminance * 3 ~/ 5);
    }
  }

  final left = width * 3 ~/ 16;
  final top = height * 7 ~/ 30;
  final cardWidth = width * 5 ~/ 8;
  final cardHeight = height * 8 ~/ 15;
  img.fillRect(
    image,
    x1: left,
    y1: top,
    x2: left + cardWidth,
    y2: top + cardHeight,
    color: img.ColorRgb8(220, 225, 215),
  );
  // Portrait placeholder.
  img.fillRect(
    image,
    x1: left + cardWidth ~/ 20,
    y1: top + cardHeight ~/ 5,
    x2: left + cardWidth * 3 ~/ 10,
    y2: top + cardHeight * 4 ~/ 5,
    color: img.ColorRgb8(150, 128, 105),
  );
  const lines = [
    'Name: MD EXAMPLE PERSON',
    'Father: MD EXAMPLE FATHER',
    'Date of Birth: 01 Jan 1990',
    'ID NO: 1234 5678 9012',
  ];
  for (var i = 0; i < lines.length; i++) {
    img.drawString(
      image,
      lines[i],
      font: img.arial24,
      x: left + cardWidth * 2 ~/ 5,
      y: top + cardHeight ~/ 5 + i * cardHeight ~/ 7,
      color: img.ColorRgb8(20, 20, 30),
    );
  }

  return blurRadius > 0 ? img.gaussianBlur(image, radius: blurRadius) : image;
}

/// Well exposed white page filled with lines of dark text, 1200x1600.
img.Image documentPageImage({int width = 1200, int height = 1600}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(236, 236, 230));
  for (var y = height ~/ 16; y < height - height ~/ 16; y += 40) {
    img.drawString(
      image,
      'Lorem ipsum dolor sit amet 12345 ABCDEFG',
      font: img.arial24,
      x: width ~/ 16,
      y: y,
      color: img.ColorRgb8(25, 25, 25),
    );
  }
  return image;
}
