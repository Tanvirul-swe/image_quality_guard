import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:image_quality_guard/src/detectors/sharpness_detector.dart';
import 'package:image_quality_guard/src/models/sharpness_result.dart';

import '../config/image_quality_config.dart';
import '../detectors/brightness_detector.dart';
import '../detectors/contrast_detector.dart';
import '../models/image_quality_exception.dart';
import '../models/image_quality_result.dart';
import 'luminance_extractor.dart';
import 'luminance_statistics.dart';

/// A decoded image reduced to the data the detectors actually need.
///
/// Everything in this class is isolate safe: a flat [Uint8List] luminance
/// buffer and integers. The decoded `package:image` object is released as soon
/// as the buffer is built, which keeps the memory peak of a large photo lower
/// than keeping the decoded image around for every detector.
class PreparedImage {
  /// Creates a prepared image description.
  const PreparedImage({
    required this.luminance,
    required this.width,
    required this.height,
    required this.originalWidth,
    required this.originalHeight,
  });

  /// One luminance sample per pixel, row major.
  final Uint8List luminance;

  /// Width of the analyzed image (after downsampling).
  final int width;

  /// Height of the analyzed image (after downsampling).
  final int height;

  /// Width of the image as decoded, before downsampling.
  final int originalWidth;

  /// Height of the image as decoded, before downsampling.
  final int originalHeight;

  /// Whether the image was downsampled before being analyzed.
  bool get downsampled => width != originalWidth || height != originalHeight;

  /// Number of luminance samples that were analyzed.
  int get pixelCount => width * height;

  @override
  String toString() => 'PreparedImage(analyzed: ${width}x$height, '
      'original: ${originalWidth}x$originalHeight, samples: $pixelCount)';
}

/// Metrics produced by a single analysis pass over a [PreparedImage].
class ImageAnalysisMetrics {
  const ImageAnalysisMetrics({
    required this.sharpness,
    required this.brightness,
    required this.contrast,
  });

  final SharpnessResult sharpness;

  final double brightness;

  final double contrast;
}

/// Runs every CPU heavy step of the image quality check.
///
/// The class is stateless and only depends on `package:image`, primitives and
/// [Uint8List] buffers, which is what makes it safe to execute inside a
/// background isolate:
///
/// ```text
/// decode -> optional downsampling -> grayscale luminance -> blur/brightness/contrast
/// ```
///
/// The image is decoded exactly once and reused by every detector, and blur,
/// brightness and contrast are derived from the same luminance buffer.
abstract final class ImageProcessor {
  /// Decodes [imageBytes] and prepares the luminance buffer.
  ///
  /// The longest side is limited to [maxAnalysisDimension] while the aspect
  /// ratio is preserved; smaller images are never upscaled and a
  /// [maxAnalysisDimension] of `0` disables downsampling entirely.
  ///
  /// Throws an [ImageDecodeException] when the bytes cannot be decoded.
  static PreparedImage prepare(
    Uint8List imageBytes, {
    required int maxAnalysisDimension,
  }) {
    if (imageBytes.isEmpty) {
      throw const ImageDecodeException(
        message: 'Cannot decode image from provided bytes',
      );
    }

    final img.Image? decoded;
    try {
      decoded = img.decodeImage(imageBytes);
    } on Object catch (error) {
      // Truncated or corrupted files can make a decoder throw instead of
      // returning null; both cases mean "not a usable image".
      throw ImageDecodeException(
        message: 'Cannot decode image from provided bytes',
        cause: '$error',
      );
    }

    if (decoded == null) {
      throw const ImageDecodeException(
        message: 'Cannot decode image from provided bytes',
      );
    }

    return prepareFromImage(
      decoded,
      maxAnalysisDimension: maxAnalysisDimension,
    );
  }

  /// Prepares the luminance buffer of an already decoded [image].
  ///
  /// The [image] itself is never modified.
  static PreparedImage prepareFromImage(
    img.Image image, {
    required int maxAnalysisDimension,
  }) {
    // Normalize palette and high dynamic range images, and flatten multi frame
    // containers, before any pixel is read.
    var source = LuminanceExtractor.normalize(image);

    // EXIF orientations 5-8 transpose the image, so the visually correct size is
    // the swapped one. `copyResize` applies the orientation internally, which
    // keeps the reported dimensions and the analyzed dimensions aligned.
    final transposed = _isTransposed(source);
    var originalWidth = transposed ? source.height : source.width;
    var originalHeight = transposed ? source.width : source.height;

    var analyzedWidth = originalWidth;
    var analyzedHeight = originalHeight;

    if (maxAnalysisDimension > 0) {
      final longestSide = math.max(originalWidth, originalHeight);
      if (longestSide > maxAnalysisDimension) {
        final scale = maxAnalysisDimension / longestSide;
        analyzedWidth = math.max(1, (originalWidth * scale).round());
        analyzedHeight = math.max(1, (originalHeight * scale).round());
        // Area averaging keeps the reduced image free of the aliasing that a
        // nearest neighbour reduction would add, which matters because blur
        // detection measures exactly that kind of detail.
        source = img.copyResize(
          source,
          width: analyzedWidth,
          height: analyzedHeight,
          interpolation: img.Interpolation.average,
        );
      }
    }

    return PreparedImage(
      luminance: LuminanceExtractor.fromImage(source),
      width: analyzedWidth,
      height: analyzedHeight,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
    );
  }

  /// Runs blur, brightness and contrast over a [prepared] image.
  ///
  /// One traversal of the luminance buffer feeds brightness and contrast, a
  /// second traversal feeds the Laplacian blur score. Neither traversal
  /// allocates a value per pixel, so memory use stays proportional to the
  /// luminance buffer itself. New CPU intensive metrics only need to be added
  /// here to run inside the background isolate as well.
  static ImageAnalysisMetrics analyze(
    PreparedImage prepared, {
    required ImageQualityConfig config,
  }) {
    final luminanceStatistics = summarizeLuminance(
      prepared.luminance,
    );

    final sharpness = SharpnessDetector.analyze(
      prepared.luminance,
      width: prepared.width,
      height: prepared.height,
      blurThreshold: config.blurThreshold,
      denoise: config.denoiseBeforeSharpness,
      tileRows: config.tileRows,
      tileColumns: config.tileColumns,
      minTileContrast: config.minTileContrast,
      minInformativeTiles: config.minInformativeTiles,
      minSharpTileRatio: config.minSharpTileRatio,
      minTenengradScore: config.minTenengradScore,
    );

    return ImageAnalysisMetrics(
      sharpness: sharpness,
      brightness: luminanceStatistics.mean,
      contrast: luminanceStatistics.standardDeviation,
    );
  }

  /// Decodes and analyzes [imageBytes] on the calling isolate.
  ///
  /// `ImageQualityGuard.analyze` runs this exact pipeline inside a background
  /// isolate; this method exists for the explicit synchronous API.
  static ImageQualityResult processBytes(
    Uint8List imageBytes, {
    required ImageQualityConfig config,
  }) {
    final stopwatch = Stopwatch()..start();
    final prepared = prepare(
      imageBytes,
      maxAnalysisDimension: config.maxAnalysisDimension,
    );
    final metrics = analyze(prepared, config: config);
    stopwatch.stop();
    return buildResult(
      prepared: prepared,
      metrics: metrics,
      config: config,
      processingTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Analyzes an already decoded [image] on the calling isolate.
  static ImageQualityResult processFromImage(
    img.Image image, {
    required ImageQualityConfig config,
  }) {
    final stopwatch = Stopwatch()..start();
    final prepared = prepareFromImage(
      image,
      maxAnalysisDimension: config.maxAnalysisDimension,
    );
    final metrics = analyze(prepared, config: config);
    stopwatch.stop();
    return buildResult(
      prepared: prepared,
      metrics: metrics,
      config: config,
      processingTimeMs: stopwatch.elapsedMilliseconds,
    );
  }

  /// Combines the measured [metrics] with the processing metadata and the
  /// thresholds of [config] into a serializable [ImageQualityResult].

  static ImageQualityResult buildResult({
    required PreparedImage prepared,
    required ImageAnalysisMetrics metrics,
    required ImageQualityConfig config,
    required int processingTimeMs,
  }) {
    final brightnessResult = BrightnessDetector(
      minBrightness: config.minBrightness,
      maxBrightness: config.maxBrightness,
    ).classify(
      metrics.brightness,
    );

    final contrastResult = ContrastDetector(
      minContrast: config.minContrast,
    ).classify(
      metrics.contrast,
    );

    return ImageQualityResult(
      isValid: !metrics.sharpness.isBlurry &&
          brightnessResult.isOptimal &&
          contrastResult.hasGoodContrast,

      // Old/raw Laplacian score
      blurScore: metrics.sharpness.rawLaplacianVariance,

      // New robust score
      sharpnessScore: metrics.sharpness.sharpnessScore,

      denoisedLaplacian: metrics.sharpness.denoisedLaplacianVariance,

      tenengradScore: metrics.sharpness.tenengradScore,

      lowTileSharpness: metrics.sharpness.lowTileSharpness,

      sharpTileRatio: metrics.sharpness.sharpTileRatio,

      informativeTileCount: metrics.sharpness.informativeTileCount,

      totalTileCount: metrics.sharpness.totalTileCount,

      brightness: metrics.brightness,

      contrast: metrics.contrast,

      originalWidth: prepared.originalWidth,

      originalHeight: prepared.originalHeight,

      analyzedWidth: prepared.width,

      analyzedHeight: prepared.height,

      processingTimeMs: processingTimeMs,

      config: config,
    );
  }

  /// Whether [image] carries an EXIF orientation that swaps width and height.
  static bool _isTransposed(img.Image image) {
    final orientation = image.exif.imageIfd.hasOrientation
        ? image.exif.imageIfd.orientation
        : 1;
    return orientation != null && orientation >= 5 && orientation <= 8;
  }
}
