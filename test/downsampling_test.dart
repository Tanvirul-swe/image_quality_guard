import 'dart:typed_data';

import 'package:image_quality_guard/image_quality_guard.dart';
import 'package:test/test.dart';

import 'test_images.dart';

/// 12 MP camera photo substitute, encoded once and reused by several tests.
/// Top level finals are initialized lazily, so the encoding only happens when a
/// test actually asks for the bytes.
final Uint8List _largePhoto = stripedPng(width: 4032, height: 3024);

/// Smaller large image, still slow enough to observe background processing.
final Uint8List _mediumPhoto = stripedPng(width: 2400, height: 1800);

void main() {
  group('ImageQualityConfig', () {
    test('defaults to a mobile friendly analysis ceiling', () {
      const config = ImageQualityConfig();

      expect(config.maxAnalysisDimension, 1280);
      expect(ImageQualityConfig.defaultMaxAnalysisDimension, 1280);
      expect(config.downscalesLargeImages, isTrue);
      expect(ImageQualityConfig.mobile, config);
    });

    test('fullResolution disables downsampling', () {
      const config = ImageQualityConfig.fullResolution;

      expect(config.maxAnalysisDimension, 0);
      expect(config.downscalesLargeImages, isFalse);
    });

    test('exposes the same presets as QualityConfig', () {
      expect(
        ImageQualityConfig.cardScanning.blurThreshold,
        QualityConfig.cardScanning.blurThreshold,
      );
      expect(
        ImageQualityConfig.documentScanning.minContrast,
        QualityConfig.documentScanning.minContrast,
      );
      expect(
        ImageQualityConfig.strict.maxBrightness,
        QualityConfig.strict.maxBrightness,
      );
    });

    test('bridges a legacy QualityConfig', () {
      final config = ImageQualityConfig.fromQualityConfig(
        QualityConfig.cardScanning,
        maxAnalysisDimension: 640,
      );

      expect(config.blurThreshold, QualityConfig.cardScanning.blurThreshold);
      expect(config.minBrightness, QualityConfig.cardScanning.minBrightness);
      expect(config.maxBrightness, QualityConfig.cardScanning.maxBrightness);
      expect(config.minContrast, QualityConfig.cardScanning.minContrast);
      expect(config.maxAnalysisDimension, 640);
    });

    test('survives a map round trip', () {
      const config = ImageQualityConfig(
        blurThreshold: 150,
        minBrightness: 30,
        maxBrightness: 240,
        minContrast: 42,
        maxAnalysisDimension: 960,
      );

      expect(ImageQualityConfig.fromMap(config.toMap()), config);
    });

    test('rejects invalid threshold combinations', () {
      expect(
        () => ImageQualityConfig(minBrightness: 200, maxBrightness: 100),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ImageQualityConfig(maxAnalysisDimension: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('downsampling', () {
    test('reduces a 12 MP photo to 1280x960', () async {
      final result = await ImageQualityGuard.analyze(_largePhoto);

      expect(result.originalWidth, 4032);
      expect(result.originalHeight, 3024);
      expect(result.analyzedWidth, 1280);
      expect(result.analyzedHeight, 960);
      expect(result.wasDownsampled, isTrue);
      expect(result.analyzedPixelCount, lessThan(4032 * 3024));
    });

    test('preserves the aspect ratio for sizes that do not divide evenly',
        () async {
      final result = await ImageQualityGuard.analyze(
        stripedPng(width: 3000, height: 1000),
      );

      expect(result.analyzedWidth, 1280);
      expect(result.analyzedHeight, 427);
      expect(
        result.analyzedWidth / result.analyzedHeight,
        closeTo(result.originalWidth / result.originalHeight, 0.01),
      );
    });

    test('downsamples the longest side of portrait images', () async {
      final result = await ImageQualityGuard.analyze(
        stripedPng(width: 1000, height: 3000),
      );

      expect(result.analyzedWidth, 427);
      expect(result.analyzedHeight, 1280);
      expect(result.originalWidth, 1000);
      expect(result.originalHeight, 3000);
    });

    test('never upscales smaller images', () async {
      final result = await ImageQualityGuard.analyze(
        stripedPng(width: 800, height: 600),
      );

      expect(result.analyzedWidth, 800);
      expect(result.analyzedHeight, 600);
      expect(result.wasDownsampled, isFalse);

      final tiny = await ImageQualityGuard.analyze(
        pngBytes(checkerboardImage()),
      );
      expect(tiny.analyzedWidth, 16);
      expect(tiny.analyzedHeight, 16);
    });

    test('honours a custom analysis dimension', () async {
      final result = await ImageQualityGuard.analyze(
        stripedPng(width: 400, height: 300),
        config: const ImageQualityConfig(maxAnalysisDimension: 100),
      );

      expect(result.analyzedWidth, 100);
      expect(result.analyzedHeight, 75);
    });

    test('analyzes the full resolution when downsampling is disabled',
        () async {
      final result = await ImageQualityGuard.analyze(
        stripedPng(width: 2000, height: 1500),
        config: ImageQualityConfig.fullResolution,
      );

      expect(result.analyzedWidth, 2000);
      expect(result.analyzedHeight, 1500);
      expect(result.wasDownsampled, isFalse);
    });

    test('analyzes already decoded images', () {
      final result = ImageQualityGuard.analyzeImageSync(
        stripedImage(width: 3000, height: 1000),
      );

      expect(result.analyzedWidth, 1280);
      expect(result.analyzedHeight, 427);
      expect(result.wasDownsampled, isTrue);
    });

    test('background and synchronous analysis agree on dimensions and metrics',
        () async {
      final fromIsolate = await ImageQualityGuard.analyze(_mediumPhoto);
      final fromSync = ImageQualityGuard.analyzeSync(_mediumPhoto);

      expect(fromIsolate.analyzedWidth, fromSync.analyzedWidth);
      expect(fromIsolate.analyzedHeight, fromSync.analyzedHeight);
      expect(fromIsolate.blurScore, fromSync.blurScore);
      expect(fromIsolate.brightness, fromSync.brightness);
      expect(fromIsolate.contrast, fromSync.contrast);
      expect(fromIsolate.isValid, fromSync.isValid);
    });

    test('keeps the metrics of the legacy full resolution validator', () async {
      const qualityConfig = QualityConfig(blurThreshold: 150);
      final bytes = stripedPng(width: 1200, height: 900);

      final legacy = await ImageQualityValidator(
        config: qualityConfig,
      ).validate(bytes);
      final guard = await ImageQualityGuard.analyze(
        bytes,
        config: ImageQualityConfig.fullResolution.copyWith(blurThreshold: 150),
      );

      expect(guard.blurScore, legacy.blurResult.variance);
      expect(guard.brightness, legacy.brightnessResult.averageBrightness);
      expect(guard.contrast, legacy.contrastResult.contrastScore);
      expect(guard.isValid, legacy.isValid);
    });
  });
}
