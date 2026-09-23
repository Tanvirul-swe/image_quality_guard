import '../config/image_quality_config.dart';
import 'brightness_level.dart';

/// Outcome of an image quality analysis.
///
/// The result is produced inside the background isolate, serialized with
/// [toMap] and rebuilt on the main isolate with [fromMap].
///
/// In addition to the legacy raw Laplacian [blurScore], the result now
/// contains more robust sharpness metrics:
///
/// - [sharpnessScore] - robust sharpness score used for blur classification
/// - [denoisedLaplacian] - whole-image Laplacian after noise reduction
/// - [tenengradScore] - Sobel/Tenengrad edge strength
/// - [lowTileSharpness] - low-percentile tile sharpness
/// - [sharpTileRatio] - percentage of informative tiles considered sharp
///
/// Example:
///
/// ```dart
/// final result = await ImageQualityGuard.analyze(imageBytes);
///
/// print('Valid: ${result.isValid}');
/// print('Blurry: ${result.isBlurry}');
/// print('Raw Laplacian: ${result.blurScore}');
/// print('Robust sharpness: ${result.sharpnessScore}');
/// print('Tenengrad: ${result.tenengradScore}');
/// print('Sharp tile ratio: ${result.sharpTileRatio}');
/// ```
class ImageQualityResult {
  /// Creates an image quality result.
  ///
  /// The new sharpness properties are optional to preserve backwards
  /// compatibility with code that creates [ImageQualityResult] manually.
  const ImageQualityResult({
    required this.isValid,
    required this.blurScore,
    required this.brightness,
    required this.contrast,
    required this.originalWidth,
    required this.originalHeight,
    required this.analyzedWidth,
    required this.analyzedHeight,
    required this.processingTimeMs,
    double? sharpnessScore,
    double? denoisedLaplacian,
    this.tenengradScore = 0.0,
    double? lowTileSharpness,
    this.sharpTileRatio = 1.0,
    this.informativeTileCount = 0,
    this.totalTileCount = 0,
    this.config = const ImageQualityConfig(),
  })  : sharpnessScore = sharpnessScore ?? blurScore,
        denoisedLaplacian = denoisedLaplacian ?? blurScore,
        lowTileSharpness = lowTileSharpness ?? blurScore;

  /// Whether the image passed all enabled quality checks.
  final bool isValid;

  // ---------------------------------------------------------------------------
  // SHARPNESS / BLUR
  // ---------------------------------------------------------------------------

  /// Legacy raw whole-image Laplacian variance.
  ///
  /// Higher values generally indicate stronger high-frequency information,
  /// but this value alone should NOT be used as the final blur decision.
  ///
  /// Camera noise, JPEG artifacts, document borders and security patterns can
  /// cause this score to become high even when text is visibly blurry.
  ///
  /// Kept for backwards compatibility and diagnostics.
  final double blurScore;

  /// Robust sharpness score used for the actual blur classification.
  ///
  /// Normally this is calculated from the median sharpness of informative
  /// image tiles after denoising.
  ///
  /// Higher = sharper.
  final double sharpnessScore;

  /// Whole-image Laplacian variance after noise reduction.
  ///
  /// This is generally more reliable than [blurScore] because camera sensor
  /// noise and compression artifacts are reduced before measurement.
  final double denoisedLaplacian;

  /// Sobel/Tenengrad sharpness score.
  ///
  /// This provides a second sharpness measurement independent of the
  /// Laplacian detector.
  ///
  /// Higher = stronger useful edges.
  final double tenengradScore;

  /// Lower-percentile sharpness of informative tiles.
  ///
  /// This helps detect images where only a small area is sharp while a large
  /// part of the image is blurry.
  final double lowTileSharpness;

  /// Fraction of informative image tiles that reached the configured
  /// sharpness threshold.
  ///
  /// Range:
  ///
  /// ```text
  /// 0.0 = 0% sharp tiles
  /// 0.5 = 50% sharp tiles
  /// 1.0 = 100% sharp tiles
  /// ```
  final double sharpTileRatio;

  /// Number of tiles that contained enough visual information to be used
  /// during sharpness analysis.
  ///
  /// Blank or extremely low-contrast regions can be excluded.
  final int informativeTileCount;

  /// Total number of image tiles evaluated.
  final int totalTileCount;

  // ---------------------------------------------------------------------------
  // BRIGHTNESS / CONTRAST
  // ---------------------------------------------------------------------------

  /// Average luminance of the analyzed image on a 0-255 scale.
  final double brightness;

  /// Standard deviation of image luminance.
  ///
  /// Higher generally means more tonal variation.
  final double contrast;

  // ---------------------------------------------------------------------------
  // IMAGE METADATA
  // ---------------------------------------------------------------------------

  /// Width before downsampling.
  final int originalWidth;

  /// Height before downsampling.
  final int originalHeight;

  /// Width actually passed to the quality analyzers.
  final int analyzedWidth;

  /// Height actually passed to the quality analyzers.
  final int analyzedHeight;

  /// Time spent decoding, preparing and analyzing the image.
  ///
  /// This does not necessarily include isolate startup/transfer overhead.
  final int processingTimeMs;

  /// Configuration used for this analysis.
  final ImageQualityConfig config;

  // ---------------------------------------------------------------------------
  // CLASSIFICATION
  // ---------------------------------------------------------------------------

  /// Whether the image should be considered blurry.
  ///
  /// The final decision can use multiple checks:
  ///
  /// 1. Robust sharpness score
  /// 2. Percentage of sharp informative tiles
  /// 3. Optional Tenengrad minimum
  ///
  /// Raw [blurScore] is intentionally NOT used directly as the main decision.
  bool get isBlurry {
    // Main robust sharpness gate.
    if (sharpnessScore < config.blurThreshold) {
      return true;
    }

    // Tile-based gate.
    //
    // Only apply it when enough informative tiles were available.
    if (informativeTileCount >= config.minInformativeTiles &&
        sharpTileRatio < config.minSharpTileRatio) {
      return true;
    }

    // Optional Tenengrad gate.
    //
    // A value of 0 disables this check.
    if (config.minTenengradScore > 0 &&
        tenengradScore < config.minTenengradScore) {
      return true;
    }

    return false;
  }

  /// Whether brightness is within the configured acceptable range.
  bool get isBrightnessOptimal => brightnessLevel == BrightnessLevel.optimal;

  /// Whether image contrast reaches the configured minimum.
  bool get hasGoodContrast => contrast >= config.minContrast;

  /// Whether the image was resized before analysis.
  bool get wasDownsampled =>
      analyzedWidth != originalWidth || analyzedHeight != originalHeight;

  /// Number of pixels analyzed.
  int get analyzedPixelCount => analyzedWidth * analyzedHeight;

  /// Percentage of informative tiles classified as sharp.
  double get sharpTilePercentage => sharpTileRatio * 100.0;

  /// Whether tile-based sharpness validation was actually available.
  bool get hasTileSharpnessData => informativeTileCount > 0;

  /// Brightness classification.
  BrightnessLevel get brightnessLevel {
    if (brightness < config.minBrightness) {
      return BrightnessLevel.tooDark;
    }

    if (brightness > config.maxBrightness) {
      return BrightnessLevel.tooBright;
    }

    return BrightnessLevel.optimal;
  }

  // ---------------------------------------------------------------------------
  // ISSUES
  // ---------------------------------------------------------------------------

  /// Human-readable list of detected quality issues.
  List<String> get issues {
    final detected = <String>[];

    if (isBlurry) {
      final buffer = StringBuffer(
        'Image is blurry '
        '(sharpness ${sharpnessScore.toStringAsFixed(2)}, '
        'threshold ${config.blurThreshold.toStringAsFixed(2)}',
      );

      if (hasTileSharpnessData) {
        buffer.write(
          ', sharp tiles '
          '${sharpTilePercentage.toStringAsFixed(0)}%',
        );
      }

      if (tenengradScore > 0) {
        buffer.write(
          ', tenengrad '
          '${tenengradScore.toStringAsFixed(2)}',
        );
      }

      buffer.write(')');

      detected.add(buffer.toString());
    }

    switch (brightnessLevel) {
      case BrightnessLevel.tooDark:
        detected.add(
          'Image is too dark '
          '(brightness ${brightness.toStringAsFixed(2)} < '
          'minimum ${config.minBrightness.toStringAsFixed(2)})',
        );

      case BrightnessLevel.tooBright:
        detected.add(
          'Image is too bright '
          '(brightness ${brightness.toStringAsFixed(2)} > '
          'maximum ${config.maxBrightness.toStringAsFixed(2)})',
        );

      case BrightnessLevel.optimal:
        break;
    }

    if (!hasGoodContrast) {
      detected.add(
        'Image has low contrast '
        '(score ${contrast.toStringAsFixed(2)} < '
        'minimum ${config.minContrast.toStringAsFixed(2)})',
      );
    }

    return detected;
  }

  /// First quality issue, or `null` if there is no issue.
  String? get errorMessage {
    if (isValid) {
      return null;
    }

    final detected = issues;

    return detected.isEmpty ? null : detected.first;
  }

  /// Short human-readable result summary.
  String get summary {
    if (isValid) {
      return 'Image quality is acceptable';
    }

    return 'Image quality issues detected: ${issues.join(', ')}';
  }

  // ---------------------------------------------------------------------------
  // SERIALIZATION
  // ---------------------------------------------------------------------------

  /// Converts this result to an isolate-safe and JSON-safe map.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'isValid': isValid,

        // Sharpness
        'blurScore': blurScore,
        'sharpnessScore': sharpnessScore,
        'denoisedLaplacian': denoisedLaplacian,
        'tenengradScore': tenengradScore,
        'lowTileSharpness': lowTileSharpness,
        'sharpTileRatio': sharpTileRatio,
        'informativeTileCount': informativeTileCount,
        'totalTileCount': totalTileCount,

        // Brightness / contrast
        'brightness': brightness,
        'contrast': contrast,

        // Metadata
        'originalWidth': originalWidth,
        'originalHeight': originalHeight,
        'analyzedWidth': analyzedWidth,
        'analyzedHeight': analyzedHeight,
        'processingTimeMs': processingTimeMs,

        // Config
        'config': config.toMap(),
      };

  /// Rebuilds an [ImageQualityResult] from [toMap].
  ///
  /// This method is also backwards compatible with old result maps that do not
  /// yet contain the new sharpness properties.
  factory ImageQualityResult.fromMap(
    Map<Object?, Object?> map,
  ) {
    final rawConfig = map['config'];

    final blurScore = _asDouble(map['blurScore']);

    return ImageQualityResult(
      isValid: map['isValid'] == true,

      // ---------------------------------------------------------------------
      // Sharpness
      // ---------------------------------------------------------------------

      blurScore: blurScore,

      sharpnessScore: map['sharpnessScore'] is num
          ? _asDouble(map['sharpnessScore'])
          : blurScore,

      denoisedLaplacian: map['denoisedLaplacian'] is num
          ? _asDouble(map['denoisedLaplacian'])
          : blurScore,

      tenengradScore: _asDouble(map['tenengradScore']),

      lowTileSharpness: map['lowTileSharpness'] is num
          ? _asDouble(map['lowTileSharpness'])
          : blurScore,

      sharpTileRatio:
          map['sharpTileRatio'] is num ? _asDouble(map['sharpTileRatio']) : 1.0,

      informativeTileCount: _asInt(map['informativeTileCount']),

      totalTileCount: _asInt(map['totalTileCount']),

      // ---------------------------------------------------------------------
      // Brightness / contrast
      // ---------------------------------------------------------------------

      brightness: _asDouble(map['brightness']),

      contrast: _asDouble(map['contrast']),

      // ---------------------------------------------------------------------
      // Image metadata
      // ---------------------------------------------------------------------

      originalWidth: _asInt(map['originalWidth']),

      originalHeight: _asInt(map['originalHeight']),

      analyzedWidth: _asInt(map['analyzedWidth']),

      analyzedHeight: _asInt(map['analyzedHeight']),

      processingTimeMs: _asInt(map['processingTimeMs']),

      // ---------------------------------------------------------------------
      // Config
      // ---------------------------------------------------------------------

      config: rawConfig is Map
          ? ImageQualityConfig.fromMap(
              rawConfig,
            )
          : const ImageQualityConfig(),
    );
  }

  // ---------------------------------------------------------------------------
  // DEBUG
  // ---------------------------------------------------------------------------

  @override
  String toString() => 'ImageQualityResult('
      'isValid: $isValid, '
      'isBlurry: $isBlurry, '
      'rawLaplacian: ${blurScore.toStringAsFixed(2)}, '
      'denoisedLaplacian: ${denoisedLaplacian.toStringAsFixed(2)}, '
      'sharpnessScore: ${sharpnessScore.toStringAsFixed(2)}, '
      'tenengradScore: ${tenengradScore.toStringAsFixed(2)}, '
      'lowTileSharpness: ${lowTileSharpness.toStringAsFixed(2)}, '
      'sharpTileRatio: ${sharpTileRatio.toStringAsFixed(2)}, '
      'informativeTiles: $informativeTileCount/$totalTileCount, '
      'brightness: ${brightness.toStringAsFixed(2)}, '
      'contrast: ${contrast.toStringAsFixed(2)}, '
      'original: ${originalWidth}x$originalHeight, '
      'analyzed: ${analyzedWidth}x$analyzedHeight, '
      'processingTimeMs: $processingTimeMs'
      ')';

  // ---------------------------------------------------------------------------
  // EQUALITY
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageQualityResult &&
          runtimeType == other.runtimeType &&
          isValid == other.isValid &&
          blurScore == other.blurScore &&
          sharpnessScore == other.sharpnessScore &&
          denoisedLaplacian == other.denoisedLaplacian &&
          tenengradScore == other.tenengradScore &&
          lowTileSharpness == other.lowTileSharpness &&
          sharpTileRatio == other.sharpTileRatio &&
          informativeTileCount == other.informativeTileCount &&
          totalTileCount == other.totalTileCount &&
          brightness == other.brightness &&
          contrast == other.contrast &&
          originalWidth == other.originalWidth &&
          originalHeight == other.originalHeight &&
          analyzedWidth == other.analyzedWidth &&
          analyzedHeight == other.analyzedHeight &&
          processingTimeMs == other.processingTimeMs &&
          config == other.config;

  @override
  int get hashCode => Object.hash(
        isValid,
        blurScore,
        sharpnessScore,
        denoisedLaplacian,
        tenengradScore,
        lowTileSharpness,
        sharpTileRatio,
        informativeTileCount,
        totalTileCount,
        brightness,
        contrast,
        originalWidth,
        originalHeight,
        analyzedWidth,
        analyzedHeight,
        processingTimeMs,
        config,
      );
}

/// Reads a numeric payload value as double.
double _asDouble(Object? value) => value is num ? value.toDouble() : 0.0;
 
/// Reads a numeric payload value as int.
int _asInt(Object? value) => value is num ? value.toInt() : 0;
