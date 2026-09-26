import 'package:image_quality_guard/image_quality_guard.dart';
import 'package:test/test.dart';

import 'test_images.dart';

void main() {
  group('card capture sharpness', () {
    // Regression: a sharp card photo used to score far below the NID threshold
    // because Gaussian pre-smoothing and a median over mostly smooth tiles
    // (table, plain card surface, portrait) hid the detail of the text lines.
    test('accepts a sharp card photo with the NID preset', () {
      final result = ImageQualityGuard.analyzeSync(
        jpegBytes(cardPhotoImage(), quality: 92),
        config: ImageQualityConfig.nidCapture,
      );

      expect(result.isBlurry, isFalse, reason: '$result');
      expect(
        result.sharpnessScore,
        greaterThan(ImageQualityConfig.nidCapture.blurThreshold),
      );
    });

    test('rejects an out of focus card photo with the NID preset', () {
      final result = ImageQualityGuard.analyzeSync(
        jpegBytes(cardPhotoImage(blurRadius: 6), quality: 92),
        config: ImageQualityConfig.nidCapture,
      );

      expect(result.isBlurry, isTrue, reason: '$result');
      expect(result.isValid, isFalse);
    });

    test('scores the sharp photo well above the blurred one', () {
      double score(int blurRadius) => ImageQualityGuard.analyzeSync(
            jpegBytes(cardPhotoImage(blurRadius: blurRadius), quality: 92),
            config: ImageQualityConfig.nidCapture,
          ).sharpnessScore;

      expect(score(0), greaterThan(score(3)));
      expect(score(3), greaterThan(score(6)));
    });

    test('keeps pre-smoothing and the tile coverage gate opt-in', () {
      const config = ImageQualityConfig();

      expect(config.denoiseBeforeSharpness, isFalse);
      expect(config.minSharpTileRatio, 0);
      expect(ImageQualityConfig.nidCapture.denoiseBeforeSharpness, isFalse);
      expect(ImageQualityConfig.nidCapture.minSharpTileRatio, 0);
      expect(ImageQualityConfig.cardScanning.minSharpTileRatio, 0);
      expect(ImageQualityConfig.fromMap(const {}), config);
    });
  });
}
