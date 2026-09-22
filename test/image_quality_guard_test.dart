import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_quality_guard/image_quality_guard.dart';
import 'package:test/test.dart';

void main() {
  group('QualityConfig', () {
    test('provides documented defaults', () {
      const config = QualityConfig();

      expect(config.blurThreshold, 100);
      expect(config.minBrightness, 40);
      expect(config.maxBrightness, 220);
      expect(config.minContrast, 50);
    });

    test('copyWith changes only selected thresholds', () {
      final config = QualityConfig.cardScanning.copyWith(
        blurThreshold: 140,
      );

      expect(config.blurThreshold, 140);
      expect(config.minBrightness, QualityConfig.cardScanning.minBrightness);
      expect(config.maxBrightness, QualityConfig.cardScanning.maxBrightness);
      expect(config.minContrast, QualityConfig.cardScanning.minContrast);
    });

    test('rejects invalid threshold combinations', () {
      expect(
        () => QualityConfig(minBrightness: 200, maxBrightness: 100),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => QualityConfig(blurThreshold: 0),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('BrightnessAnalyzer', () {
    const analyzer = BrightnessAnalyzer();

    test('classifies dark, optimal, and bright images', () {
      final dark = analyzer.analyzeFromImage(_solidImage(10));
      final optimal = analyzer.analyzeFromImage(_solidImage(128));
      final bright = analyzer.analyzeFromImage(_solidImage(245));

      expect(dark.level, BrightnessLevel.tooDark);
      expect(optimal.level, BrightnessLevel.optimal);
      expect(optimal.averageBrightness, closeTo(128, 0.01));
      expect(bright.level, BrightnessLevel.tooBright);
    });
  });

  group('ContrastAnalyzer', () {
    const analyzer = ContrastAnalyzer();

    test('rejects a flat image', () {
      final result = analyzer.analyzeFromImage(_solidImage(128));

      expect(result.hasGoodContrast, isFalse);
      expect(result.contrastScore, closeTo(0, 0.01));
    });

    test('accepts a black and white pattern', () {
      final result = analyzer.analyzeFromImage(_checkerboardImage());

      expect(result.hasGoodContrast, isTrue);
      expect(result.contrastScore, greaterThan(100));
    });
  });

  group('BlurDetector', () {
    const detector = BlurDetector();

    test('classifies a flat image as blurry', () {
      final result = detector.detectFromImage(_solidImage(128));

      expect(result.isBlurry, isTrue);
      expect(result.variance, 0);
      expect(result.confidence, inInclusiveRange(0, 1));
    });

    test('classifies a high-frequency pattern as sharp', () {
      final result = detector.detectFromImage(_checkerboardImage());

      expect(result.isBlurry, isFalse);
      expect(result.variance, greaterThan(result.threshold));
    });
  });

  group('ImageQualityValidator', () {
    final validator = ImageQualityValidator();

    test('accepts an image that passes every check', () async {
      final result = await validator.validateFromImage(_checkerboardImage());

      expect(result.isValid, isTrue);
      expect(result.issues, isEmpty);
      expect(result.errorMessage, isNull);
      expect(result.summary, 'Image quality is acceptable');
    });

    test('returns all issues for a flat image', () async {
      final result = await validator.validateFromImage(_solidImage(128));

      expect(result.isValid, isFalse);
      expect(
        result.issues,
        ['Image is blurry', 'Image has low contrast'],
      );
      expect(result.errorMessage, 'Image is blurry');
    });

    test('produces the same result from encoded bytes', () async {
      final image = _checkerboardImage();
      final bytes = Uint8List.fromList(img.encodePng(image));

      final fromBytes = await validator.validate(bytes);
      final fromImage = await validator.validateFromImage(image);

      expect(fromBytes, fromImage);
      expect(validator.checkBlur(bytes), fromImage.blurResult);
      expect(validator.checkBrightness(bytes), fromImage.brightnessResult);
      expect(validator.checkContrast(bytes), fromImage.contrastResult);
    });

    test('throws ArgumentError for invalid image bytes', () async {
      await expectLater(
        validator.validate(Uint8List.fromList([1, 2, 3, 4])),
        throwsArgumentError,
      );
    });

    test('uses custom thresholds', () async {
      final strictContrast = ImageQualityValidator(
        config: const QualityConfig(minContrast: 130),
      );

      final result = await strictContrast.validateFromImage(
        _checkerboardImage(),
      );

      expect(result.contrastResult.hasGoodContrast, isFalse);
      expect(result.isValid, isFalse);
    });
  });
}

img.Image _solidImage(int luminance) {
  final image = img.Image(width: 16, height: 16);
  img.fill(
    image,
    color: img.ColorRgb8(luminance, luminance, luminance),
  );
  return image;
}

img.Image _checkerboardImage() {
  final image = img.Image(width: 16, height: 16);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final luminance = (x + y).isEven ? 0 : 255;
      image.setPixelRgb(x, y, luminance, luminance, luminance);
    }
  }
  return image;
}
