import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:image_quality_guard/image_quality_guard.dart';
// White box imports: these tests cover the isolate plumbing that the public API
// builds on, including the serializable job payload and response.
import 'package:image_quality_guard/src/processing/analysis_job.dart';
import 'package:image_quality_guard/src/processing/isolate_processor.dart';
import 'package:test/test.dart';

import 'test_images.dart';

/// 4.3 MP image, encoded once and reused. Large enough that the analysis takes
/// noticeably longer than one event loop turn. Top level finals are initialized
/// lazily, so the encoding only happens when a test asks for the bytes.
final Uint8List _largePhoto = stripedPng(width: 2400, height: 1800);

void main() {
  group('ImageQualityGuard.analyze', () {
    test('analyzes a small image', () async {
      final result = await ImageQualityGuard.analyze(
        pngBytes(checkerboardImage(width: 64, height: 64)),
      );

      expect(result.isValid, isTrue);
      expect(result.isBlurry, isFalse);
      expect(result.brightness, closeTo(127.5, 0.5));
      expect(result.contrast, greaterThan(100));
      expect(result.blurScore, greaterThan(result.config.blurThreshold));
      expect(result.wasDownsampled, isFalse);
      expect(result.processingTimeMs, greaterThanOrEqualTo(0));
      expect(result.issues, isEmpty);
      expect(result.errorMessage, isNull);
      expect(result.summary, 'Image quality is acceptable');
    });

    test('reports the measured metrics and metadata', () async {
      final result = await ImageQualityGuard.analyze(
        pngBytes(solidImage(128, width: 32, height: 32)),
      );

      expect(result.isValid, isFalse);
      expect(result.isBlurry, isTrue);
      expect(result.hasGoodContrast, isFalse);
      expect(result.isBrightnessOptimal, isTrue);
      expect(result.brightnessLevel, BrightnessLevel.optimal);
      expect(result.brightness, closeTo(128, 0.01));
      expect(result.analyzedPixelCount, 32 * 32);
      expect(result.issues, hasLength(2));
      expect(result.errorMessage, isNotNull);
    });

    test('exposes the processor for dependency injection', () async {
      const processor = IsolateProcessor();

      final result = await processor.analyze(
        pngBytes(checkerboardImage(width: 32, height: 32)),
      );

      expect(result.isValid, isTrue);
      expect(
          processor
              .analyzeSync(pngBytes(checkerboardImage(width: 32, height: 32)))
              .isValid,
          isTrue);
    });
  });

  group('error handling', () {
    test('rejects empty bytes', () async {
      await expectLater(
        ImageQualityGuard.analyze(Uint8List(0)),
        throwsA(isA<ImageDecodeException>()),
      );
    });

    test('rejects unsupported bytes', () async {
      final random = Uint8List.fromList(
        List<int>.generate(512, (index) => (index * 37) % 256),
      );

      await expectLater(
        ImageQualityGuard.analyze(random),
        throwsA(isA<ImageDecodeException>()),
      );
    });

    test('rejects corrupted (truncated) images', () async {
      final png = pngBytes(stripedImage(width: 64, height: 64));
      final truncated = Uint8List.fromList(png.sublist(0, png.length ~/ 2));

      await expectLater(
        ImageQualityGuard.analyze(truncated),
        throwsA(isA<ImageDecodeException>()),
      );
    });

    test('reports decode failures with a typed exception', () async {
      try {
        await ImageQualityGuard.analyze(Uint8List.fromList([1, 2, 3, 4]));
        fail('expected a decode failure');
      } on ImageDecodeException catch (error) {
        expect(error.type, ImageQualityErrorType.decode);
        expect(error.message, 'Cannot decode image from provided bytes');
        expect(error, isA<ImageQualityException>());
        expect(error.toString(), contains('ImageDecodeException'));
      }
    });

    test('throws the same typed error from the synchronous API', () {
      expect(
        () => ImageQualityGuard.analyzeSync(Uint8List(0)),
        throwsA(isA<ImageDecodeException>()),
      );
    });

    test('turns a malformed job payload into a typed analysis failure', () {
      final response = runImageQualityJob(<String, dynamic>{});

      expect(response[responseStatusKey], jobStatusFailure);
      expect(
          response[responseErrorTypeKey], ImageQualityErrorType.analysis.name);
      expect(
        () => decodeImageQualityResponse(response),
        throwsA(isA<ImageAnalysisException>()),
      );
    });

    test('keeps the legacy ArgumentError contract of the validator', () async {
      await expectLater(
        ImageQualityValidator().validate(Uint8List(0)),
        throwsArgumentError,
      );
      expect(
        () => ImageQualityValidator().checkBlur(Uint8List.fromList([1, 2, 3])),
        throwsArgumentError,
      );
    });
  });

  group('result serialization', () {
    test('round trips through JSON', () {
      const result = ImageQualityResult(
        isValid: true,
        blurScore: 180.42,
        brightness: 126.4,
        contrast: 54.3,
        originalWidth: 4032,
        originalHeight: 3024,
        analyzedWidth: 1280,
        analyzedHeight: 960,
        processingTimeMs: 72,
        config: ImageQualityConfig(blurThreshold: 120),
      );

      final decoded = ImageQualityResult.fromMap(
        jsonDecode(jsonEncode(result.toMap())) as Map<String, dynamic>,
      );

      expect(decoded, result);
    });

    test('round trips a real analysis result through JSON', () async {
      final result = await ImageQualityGuard.analyze(
        pngBytes(checkerboardImage(width: 32, height: 32)),
      );

      final decoded = ImageQualityResult.fromMap(
        jsonDecode(jsonEncode(result.toMap())) as Map<String, dynamic>,
      );

      expect(decoded, result);
    });

    test('tolerates a payload without a config', () {
      final decoded = ImageQualityResult.fromMap(<String, dynamic>{
        'isValid': true,
        'blurScore': 10,
      });

      expect(decoded.config, const ImageQualityConfig());
      expect(decoded.blurScore, 10);
      expect(decoded.brightness, 0);
      expect(decoded.analyzedWidth, 0);
    });

    test('maps serialized error types back to exception subclasses', () {
      expect(
        ImageQualityException.fromType(ImageQualityErrorType.decode, 'x'),
        isA<ImageDecodeException>(),
      );
      expect(
        ImageQualityException.fromType(ImageQualityErrorType.analysis, 'x'),
        isA<ImageAnalysisException>(),
      );
      expect(
        ImageQualityException.fromType(
          ImageQualityErrorType.isolate,
          'x',
          cause: 'boom',
        ),
        isA<ImageIsolateException>(),
      );
    });

    test('produces a serializable job response', () {
      final response = runImageQualityJob(
        buildImageQualityPayload(
          pngBytes(checkerboardImage(width: 32, height: 32)),
          ImageQualityConfig.fullResolution,
        ),
      );

      expect(response[responseStatusKey], jobStatusSuccess);

      // The response only contains primitives, lists and maps, so it survives a
      // JSON round trip without any custom decoder.
      final decodedResponse =
          jsonDecode(jsonEncode(response)) as Map<String, dynamic>;
      final result = decodeImageQualityResponse(decodedResponse);

      expect(result.isValid, isTrue);
      expect(result.analyzedWidth, 32);
      expect(result.config, ImageQualityConfig.fullResolution);
    });

    test('produces a serializable decode failure response', () {
      final response = runImageQualityJob(
        buildImageQualityPayload(
          Uint8List.fromList([9, 9, 9]),
          const ImageQualityConfig(),
        ),
      );

      expect(response[responseStatusKey], jobStatusFailure);
      expect(response[responseErrorTypeKey], ImageQualityErrorType.decode.name);
      expect(
        () => decodeImageQualityResponse(response),
        throwsA(isA<ImageDecodeException>()),
      );
    });
  });

  group('multiple analyses', () {
    test('handles sequential analyses', () async {
      final bytes = stripedPng(width: 1024, height: 768);
      final results = <ImageQualityResult>[];

      for (var index = 0; index < 4; index++) {
        results.add(await ImageQualityGuard.analyze(bytes));
      }

      for (final result in results) {
        expect(result.blurScore, results.first.blurScore);
        expect(result.brightness, results.first.brightness);
        expect(result.analyzedWidth, 1024);
      }
    });

    test('handles concurrent analyses', () async {
      final bytes = stripedPng(width: 1024, height: 768);

      final results = await Future.wait(
        List.generate(3, (_) => ImageQualityGuard.analyze(bytes)),
      );

      expect(results, hasLength(3));
      expect(results.map((result) => result.blurScore).toSet(), hasLength(1));
      expect(results.every((result) => result.isValid), isTrue);
    });
  });

  group('main isolate responsiveness', () {
    test('keeps the event loop free while analyzing a large image', () async {
      var ticks = 0;
      final timer =
          Timer.periodic(const Duration(milliseconds: 5), (_) => ticks++);

      final result = await ImageQualityGuard.analyze(_largePhoto);
      final ticksWhileAnalyzing = ticks;
      timer.cancel();

      expect(result.analyzedWidth, 1280);
      expect(ticksWhileAnalyzing, greaterThanOrEqualTo(2),
          reason: 'the main isolate must keep processing events while the '
              'analysis runs on a background isolate');
    });

    test('blocks the event loop when analysis runs on the caller', () {
      var ticks = 0;
      final timer =
          Timer.periodic(const Duration(milliseconds: 5), (_) => ticks++);

      ImageQualityGuard.analyzeSync(_largePhoto);
      timer.cancel();

      expect(ticks, 0,
          reason: 'synchronous analysis is expected to run on this isolate');
    });
  });
}
