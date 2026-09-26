import 'package:image/image.dart' as img;
import 'package:image_quality_guard/image_quality_guard.dart';
import 'package:test/test.dart';

import 'test_images.dart';

void main() {
  group('glare', () {
    test('rejects a card photo with a reflection over the text', () {
      final photo = cardPhotoImage();
      img.fillCircle(
        photo,
        x: 900,
        y: 600,
        radius: 220,
        color: img.ColorRgb8(255, 255, 255),
      );

      final result = ImageQualityGuard.analyzeSync(
        jpegBytes(photo, quality: 92),
        config: ImageQualityConfig.nidCapture,
      );

      expect(result.glareRatio, greaterThan(0.03));
      expect(result.hasGlare, isTrue);
      expect(result.isValid, isFalse);
      expect(result.issues, contains(startsWith('Image has glare')));
    });

    test('accepts a card photo without blown out pixels', () {
      final result = ImageQualityGuard.analyzeSync(
        jpegBytes(cardPhotoImage(), quality: 92),
        config: ImageQualityConfig.nidCapture,
      );

      expect(result.hasGlare, isFalse);
      expect(result.isValid, isTrue, reason: '$result');
    });

    test('is disabled unless a preset or config enables it', () {
      expect(const ImageQualityConfig().maxGlareRatio, 1.0);
      expect(ImageQualityConfig.photoCapture.maxGlareRatio, 1.0);
      expect(ImageQualityConfig.cardScanning.maxGlareRatio, lessThan(1));
      expect(ImageQualityConfig.documentScanning.maxGlareRatio, lessThan(1));
      expect(ImageQualityConfig.nidCapture.maxGlareRatio, lessThan(1));
    });

    test('survives a result round trip', () {
      final result = ImageQualityGuard.analyzeSync(
        jpegBytes(cardPhotoImage(), quality: 92),
        config: ImageQualityConfig.nidCapture,
      );

      expect(ImageQualityResult.fromMap(result.toMap()), result);
    });
  });

  group('document preset', () {
    // A clean page is mostly white paper: high mean brightness and a low
    // standard deviation, which the previous thresholds rejected.
    test('accepts a well exposed page of text', () {
      final result = ImageQualityGuard.analyzeSync(
        jpegBytes(documentPageImage(), quality: 92),
        config: ImageQualityConfig.documentScanning,
      );

      expect(result.isValid, isTrue, reason: '$result');
    });
  });

  group('sharp area coverage', () {
    // A sharp card lying on a table: its text is in focus, but the table and
    // plain card surface keep most tiles below the document threshold.
    final result = ImageQualityGuard.analyzeSync(
      jpegBytes(cardPhotoImage(), quality: 92),
      config: ImageQualityConfig.documentScanning,
    );

    test('reports low coverage separately from focus', () {
      expect(result.isOutOfFocus, isFalse, reason: '$result');
      expect(result.hasLowSharpCoverage, isTrue);
      expect(result.isBlurry, isTrue);
      expect(result.isValid, isFalse);
    });

    test('explains the coverage issue instead of calling it blurry', () {
      expect(result.issues, isNot(contains(startsWith('Image is blurry'))));
      expect(result.issues, contains(contains('fill the frame')));
    });
  });

  group('analysis resolution', () {
    test('full resolution scores sharpness on the calibrated scale', () {
      final bytes = jpegBytes(cardPhotoImage(width: 2400, height: 1800));

      final mobile = ImageQualityGuard.analyzeSync(
        bytes,
        config: ImageQualityConfig.mobile,
      );
      final full = ImageQualityGuard.analyzeSync(
        bytes,
        config: ImageQualityConfig.fullResolution,
      );

      expect(full.analyzedWidth, 2400);
      expect(
        full.sharpnessScore,
        closeTo(mobile.sharpnessScore, mobile.sharpnessScore * 0.05),
      );
      expect(full.isBlurry, mobile.isBlurry);
      // The legacy raw score keeps the analyzed (full) resolution.
      expect(full.blurScore, isNot(closeTo(mobile.blurScore, 1)));
    });
  });
}
