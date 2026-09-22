import 'quality_config.dart';

/// Configuration for the background image quality analysis.
///
/// In addition to the quality thresholds of [QualityConfig], this class holds
/// the resolution ceiling used by the processing isolate:
///
/// * [maxAnalysisDimension] is the longest side, in pixels, that is fed to the
///   analyzers. Larger images are downsampled with area averaging while the
///   aspect ratio is preserved, and smaller images are never upscaled.
/// * A value of `0` disables downsampling and analyzes the full resolution.
///
/// Thresholds are evaluated at the *analyzed* resolution. The Laplacian
/// variance used for blur detection scales with image size, so calibrate
/// [blurThreshold] against the [maxAnalysisDimension] you ship with. Images
/// smaller than [maxAnalysisDimension] are analyzed at their own resolution and
/// therefore keep the resolution their thresholds were tuned for.
///
/// ```dart
/// final result = await ImageQualityGuard.analyze(
///   imageBytes,
///   config: const ImageQualityConfig(maxAnalysisDimension: 1280),
/// );
/// ```
class ImageQualityConfig {
  /// Creates a configuration with the given thresholds and resolution ceiling.
  ///
  /// The defaults match [QualityConfig] and analyze images at up to
  /// [defaultMaxAnalysisDimension] pixels on the longest side, which is a good
  /// balance between speed and enough detail for blur detection.
  const ImageQualityConfig({
    this.blurThreshold = 100.0,
    this.minBrightness = 40.0,
    this.maxBrightness = 220.0,
    this.minContrast = 50.0,
    this.maxAnalysisDimension = defaultMaxAnalysisDimension,
  })  : assert(blurThreshold > 0, 'blurThreshold must be positive'),
        assert(minBrightness >= 0 && minBrightness <= 255,
            'minBrightness must be between 0 and 255'),
        assert(maxBrightness >= 0 && maxBrightness <= 255,
            'maxBrightness must be between 0 and 255'),
        assert(minBrightness < maxBrightness,
            'minBrightness must be less than maxBrightness'),
        assert(minContrast >= 0, 'minContrast must be non-negative'),
        assert(maxAnalysisDimension >= 0,
            'maxAnalysisDimension must be non-negative, use 0 to disable '
            'downsampling');

  /// Longest side, in pixels, used for the analysis of large images.
  ///
  /// 1280 keeps enough detail for Laplacian based blur detection while cutting
  /// the analyzed pixel count of a 12 MP camera photo by roughly 90%.
  static const int defaultMaxAnalysisDimension = 1280;

  /// Threshold for blur detection using Laplacian variance.
  /// Higher values require sharper images.
  final double blurThreshold;

  /// Minimum acceptable brightness value (0-255 scale).
  final double minBrightness;

  /// Maximum acceptable brightness value (0-255 scale).
  final double maxBrightness;

  /// Minimum acceptable contrast score (standard deviation of luminance).
  final double minContrast;

  /// Longest side, in pixels, used while analyzing. `0` disables downsampling.
  final int maxAnalysisDimension;

  /// Whether images larger than [maxAnalysisDimension] are downsampled.
  bool get downscalesLargeImages => maxAnalysisDimension > 0;

  /// Recommended defaults for camera images on mobile devices.
  static const ImageQualityConfig mobile = ImageQualityConfig();

  /// Analyzes the full resolution, matching the pre-isolate behaviour of
  /// [QualityConfig]. Slower for large photos, but the metrics are identical to
  /// the ones produced by earlier versions.
  static const ImageQualityConfig fullResolution =
      ImageQualityConfig(maxAnalysisDimension: 0);

  /// Preset configuration optimized for card scanning (ID cards, credit cards).
  static const ImageQualityConfig cardScanning = ImageQualityConfig(
    blurThreshold: 80.0,
    minBrightness: 35.0,
    maxBrightness: 230.0,
    minContrast: 40.0,
  );

  /// Preset configuration optimized for document scanning.
  static const ImageQualityConfig documentScanning = ImageQualityConfig(
    blurThreshold: 120.0,
    minBrightness: 45.0,
    maxBrightness: 215.0,
    minContrast: 55.0,
  );

  /// Preset configuration optimized for photo capture.
  static const ImageQualityConfig photoCapture = ImageQualityConfig(
    blurThreshold: 200.0,
    minBrightness: 30.0,
    maxBrightness: 235.0,
    minContrast: 45.0,
  );

  /// Preset configuration with relaxed thresholds.
  static const ImageQualityConfig relaxed = ImageQualityConfig(
    blurThreshold: 50.0,
    minBrightness: 25.0,
    maxBrightness: 240.0,
    minContrast: 30.0,
  );

  /// Preset configuration with strict thresholds.
  static const ImageQualityConfig strict = ImageQualityConfig(
    blurThreshold: 250.0,
    minBrightness: 50.0,
    maxBrightness: 200.0,
    minContrast: 65.0,
  );

  /// Bridges a legacy [QualityConfig] into this configuration.
  ///
  /// The thresholds are copied as is, [maxAnalysisDimension] can be provided to
  /// opt into (or out of) downsampling.
  factory ImageQualityConfig.fromQualityConfig(
    QualityConfig config, {
    int maxAnalysisDimension = defaultMaxAnalysisDimension,
  }) {
    return ImageQualityConfig(
      blurThreshold: config.blurThreshold,
      minBrightness: config.minBrightness,
      maxBrightness: config.maxBrightness,
      minContrast: config.minContrast,
      maxAnalysisDimension: maxAnalysisDimension,
    );
  }

  /// Creates a copy of this config with the given fields replaced.
  ImageQualityConfig copyWith({
    double? blurThreshold,
    double? minBrightness,
    double? maxBrightness,
    double? minContrast,
    int? maxAnalysisDimension,
  }) {
    return ImageQualityConfig(
      blurThreshold: blurThreshold ?? this.blurThreshold,
      minBrightness: minBrightness ?? this.minBrightness,
      maxBrightness: maxBrightness ?? this.maxBrightness,
      minContrast: minContrast ?? this.minContrast,
      maxAnalysisDimension: maxAnalysisDimension ?? this.maxAnalysisDimension,
    );
  }

  /// Serializes this configuration into an isolate/JSON friendly map.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'blurThreshold': blurThreshold,
        'minBrightness': minBrightness,
        'maxBrightness': maxBrightness,
        'minContrast': minContrast,
        'maxAnalysisDimension': maxAnalysisDimension,
      };

  /// Rebuilds a configuration from a map produced by [toMap] or by JSON.
  ///
  /// Missing or malformed entries fall back to the documented defaults so a
  /// malformed payload never crashes the receiving isolate.
  factory ImageQualityConfig.fromMap(Map<Object?, Object?> map) {
    final maxAnalysisDimension = _asInt(
      map['maxAnalysisDimension'],
      fallback: defaultMaxAnalysisDimension,
    );
    return ImageQualityConfig(
      blurThreshold: _asDouble(map['blurThreshold'], fallback: 100.0),
      minBrightness: _asDouble(map['minBrightness'], fallback: 40.0),
      maxBrightness: _asDouble(map['maxBrightness'], fallback: 220.0),
      minContrast: _asDouble(map['minContrast'], fallback: 50.0),
      maxAnalysisDimension: maxAnalysisDimension < 0 ? 0 : maxAnalysisDimension,
    );
  }

  @override
  String toString() =>
      'ImageQualityConfig(blurThreshold: $blurThreshold, brightness: '
      '$minBrightness-$maxBrightness, minContrast: $minContrast, '
      'maxAnalysisDimension: $maxAnalysisDimension)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImageQualityConfig &&
          runtimeType == other.runtimeType &&
          blurThreshold == other.blurThreshold &&
          minBrightness == other.minBrightness &&
          maxBrightness == other.maxBrightness &&
          minContrast == other.minContrast &&
          maxAnalysisDimension == other.maxAnalysisDimension;

  @override
  int get hashCode =>
      blurThreshold.hashCode ^
      minBrightness.hashCode ^
      maxBrightness.hashCode ^
      minContrast.hashCode ^
      maxAnalysisDimension.hashCode;
}

/// Reads a numeric payload entry as a [double].
double _asDouble(Object? value, {required double fallback}) =>
    value is num ? value.toDouble() : fallback;

/// Reads a numeric payload entry as an [int].
int _asInt(Object? value, {required int fallback}) =>
    value is num ? value.toInt() : fallback;
