import '../config/image_quality_config.dart';
import 'brightness_level.dart';

/// Outcome of an image quality analysis.
///
/// The result is produced inside the background isolate, serialized with
/// [toMap] and rebuilt on the main isolate with [fromMap]. Only primitives,
/// lists and maps cross the isolate boundary.
///
/// ```dart
/// final result = await ImageQualityGuard.analyze(imageBytes);
///
/// print(result.isValid);
/// print(result.blurScore);
/// print('${result.analyzedWidth}x${result.analyzedHeight} in '
///     '${result.processingTimeMs} ms');
/// ```
class ImageQualityResult {
  /// Creates a result with the measured metrics and processing metadata.
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
    this.config = const ImageQualityConfig(),
  });

  /// Whether the image passed the blur, brightness and contrast checks.
  final bool isValid;

  /// Laplacian variance of the analyzed image. Higher values are sharper.
  final double blurScore;

  /// Average luminance of the analyzed image on a 0-255 scale.
  final double brightness;

  /// Standard deviation of the luminance of the analyzed image.
  final double contrast;

  /// Width of the image as it was decoded, before downsampling.
  final int originalWidth;

  /// Height of the image as it was decoded, before downsampling.
  final int originalHeight;

  /// Width of the image that was actually analyzed.
  final int analyzedWidth;

  /// Height of the image that was actually analyzed.
  final int analyzedHeight;

  /// Time spent decoding, downsampling and analyzing inside the processing
  /// isolate, in milliseconds.
  ///
  /// Isolate start-up and the payload transfer are not included, so this value
  /// describes the cost of the image pipeline itself.
  final int processingTimeMs;

  /// Configuration the analysis was executed with.
  final ImageQualityConfig config;

  /// Whether the blur score is below the configured blur threshold.
  bool get isBlurry => blurScore < config.blurThreshold;

  /// Whether the brightness is within the configured range.
  bool get isBrightnessOptimal => brightnessLevel == BrightnessLevel.optimal;

  /// Whether the contrast reached the configured minimum.
  bool get hasGoodContrast => contrast >= config.minContrast;

  /// Whether the analyzed image was downsampled before analysis.
  bool get wasDownsampled =>
      analyzedWidth != originalWidth || analyzedHeight != originalHeight;

  /// Number of pixels that were fed to the detectors.
  int get analyzedPixelCount => analyzedWidth * analyzedHeight;

  /// Brightness classification for the measured [brightness].
  BrightnessLevel get brightnessLevel {
    if (brightness < config.minBrightness) {
      return BrightnessLevel.tooDark;
    }
    if (brightness > config.maxBrightness) {
      return BrightnessLevel.tooBright;
    }
    return BrightnessLevel.optimal;
  }

  /// Human readable list of every failed check, empty when the image is valid.
  List<String> get issues {
    final detected = <String>[];
    if (isBlurry) {
      detected.add(
        'Image is blurry (score ${blurScore.toStringAsFixed(2)} < '
        'threshold ${config.blurThreshold.toStringAsFixed(2)})',
      );
    }
    switch (brightnessLevel) {
      case BrightnessLevel.tooDark:
        detected.add(
          'Image is too dark (brightness ${brightness.toStringAsFixed(2)} < '
          'minimum ${config.minBrightness.toStringAsFixed(2)})',
        );
      case BrightnessLevel.tooBright:
        detected.add(
          'Image is too bright (brightness ${brightness.toStringAsFixed(2)} > '
          'maximum ${config.maxBrightness.toStringAsFixed(2)})',
        );
      case BrightnessLevel.optimal:
        break;
    }
    if (!hasGoodContrast) {
      detected.add(
        'Image has low contrast (score ${contrast.toStringAsFixed(2)} < '
        'minimum ${config.minContrast.toStringAsFixed(2)})',
      );
    }
    return detected;
  }

  /// The first detected issue, or `null` when the image is valid.
  String? get errorMessage {
    if (isValid) {
      return null;
    }
    final detected = issues;
    return detected.isEmpty ? null : detected.first;
  }

  /// Short summary that can be shown in a debug log or a snack bar.
  String get summary => isValid
      ? 'Image quality is acceptable'
      : 'Image quality issues detected: ${issues.join(', ')}';

  /// Converts this result into an isolate and JSON friendly map.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'isValid': isValid,
        'blurScore': blurScore,
        'brightness': brightness,
        'contrast': contrast,
        'originalWidth': originalWidth,
        'originalHeight': originalHeight,
        'analyzedWidth': analyzedWidth,
        'analyzedHeight': analyzedHeight,
        'processingTimeMs': processingTimeMs,
        'config': config.toMap(),
      };

  /// Rebuilds a result from a map produced by [toMap] or by JSON.
  factory ImageQualityResult.fromMap(Map<Object?, Object?> map) {
    final rawConfig = map['config'];
    return ImageQualityResult(
      isValid: map['isValid'] == true,
      blurScore: _asDouble(map['blurScore']),
      brightness: _asDouble(map['brightness']),
      contrast: _asDouble(map['contrast']),
      originalWidth: _asInt(map['originalWidth']),
      originalHeight: _asInt(map['originalHeight']),
      analyzedWidth: _asInt(map['analyzedWidth']),
      analyzedHeight: _asInt(map['analyzedHeight']),
      processingTimeMs: _asInt(map['processingTimeMs']),
      config: rawConfig is Map
          ? ImageQualityConfig.fromMap(rawConfig)
          : const ImageQualityConfig(),
    );
  }

  @override
  String toString() => 'ImageQualityResult(isValid: $isValid, '
      'blurScore: ${blurScore.toStringAsFixed(2)}, '
      'brightness: ${brightness.toStringAsFixed(2)}, '
      'contrast: ${contrast.toStringAsFixed(2)}, '
      'original: ${originalWidth}x$originalHeight, '
      'analyzed: ${analyzedWidth}x$analyzedHeight, '
      'processingTimeMs: $processingTimeMs)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageQualityResult &&
          runtimeType == other.runtimeType &&
          isValid == other.isValid &&
          blurScore == other.blurScore &&
          brightness == other.brightness &&
          contrast == other.contrast &&
          originalWidth == other.originalWidth &&
          originalHeight == other.originalHeight &&
          analyzedWidth == other.analyzedWidth &&
          analyzedHeight == other.analyzedHeight &&
          processingTimeMs == other.processingTimeMs &&
          config == other.config;

  @override
  int get hashCode =>
      isValid.hashCode ^
      blurScore.hashCode ^
      brightness.hashCode ^
      contrast.hashCode ^
      originalWidth.hashCode ^
      originalHeight.hashCode ^
      analyzedWidth.hashCode ^
      analyzedHeight.hashCode ^
      processingTimeMs.hashCode ^
      config.hashCode;
}

/// Reads a numeric payload entry as a [double].
double _asDouble(Object? value) => value is num ? value.toDouble() : 0;

/// Reads a numeric payload entry as an [int].
int _asInt(Object? value) => value is num ? value.toInt() : 0;
