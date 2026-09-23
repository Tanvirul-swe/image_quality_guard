class ImageQualityConfig {
  const ImageQualityConfig({
    this.blurThreshold = 100.0,
    this.minBrightness = 40.0,
    this.maxBrightness = 220.0,
    this.minContrast = 50.0,
    this.maxAnalysisDimension = defaultMaxAnalysisDimension,

    // New sharpness settings
    this.denoiseBeforeSharpness = true,
    this.tileRows = 4,
    this.tileColumns = 4,
    this.minTileContrast = 8.0,
    this.minInformativeTiles = 4,
    this.minSharpTileRatio = 0.50,
    this.minTenengradScore = 0.0,
  })  : assert(blurThreshold > 0),
        assert(minBrightness >= 0 && minBrightness <= 255),
        assert(maxBrightness >= 0 && maxBrightness <= 255),
        assert(minBrightness < maxBrightness),
        assert(minContrast >= 0),
        assert(maxAnalysisDimension >= 0),
        assert(tileRows > 0),
        assert(tileColumns > 0),
        assert(minTileContrast >= 0),
        assert(minInformativeTiles >= 0),
        assert(
          minSharpTileRatio >= 0 && minSharpTileRatio <= 1,
        ),
        assert(minTenengradScore >= 0);

  static const int defaultMaxAnalysisDimension = 1280;

  final double blurThreshold;

  final double minBrightness;

  final double maxBrightness;

  final double minContrast;

  final int maxAnalysisDimension;

  /// Apply 3×3 Gaussian smoothing before measuring sharpness.
  final bool denoiseBeforeSharpness;

  final int tileRows;

  final int tileColumns;

  /// Tiles below this local contrast are ignored.
  final double minTileContrast;

  /// Minimum number of useful tiles required before tile statistics
  /// replace the global Laplacian score.
  final int minInformativeTiles;

  /// Minimum fraction of informative tiles that must pass blurThreshold.
  final double minSharpTileRatio;

  /// Optional secondary Sobel/Tenengrad gate.
  ///
  /// 0 disables this gate.
  final double minTenengradScore;

  bool get downscalesLargeImages => maxAnalysisDimension > 0;

  static const ImageQualityConfig mobile = ImageQualityConfig();

  static const ImageQualityConfig fullResolution = ImageQualityConfig(
    maxAnalysisDimension: 0,
  );

  static const ImageQualityConfig cardScanning = ImageQualityConfig(
    blurThreshold: 80,
    minBrightness: 35,
    maxBrightness: 230,
    minContrast: 40,
    minSharpTileRatio: 0.50,
  );

  static const ImageQualityConfig documentScanning = ImageQualityConfig(
    blurThreshold: 120,
    minBrightness: 45,
    maxBrightness: 215,
    minContrast: 55,
    minSharpTileRatio: 0.55,
  );

  /// Starting preset for NID / ID-card capture.
  ///
  /// These values MUST still be calibrated using your real device images.
  static const ImageQualityConfig nidCapture = ImageQualityConfig(
    blurThreshold: 80, // calibrate with real NIDs
    minBrightness: 55,
    maxBrightness: 225,
    minContrast: 25,

    denoiseBeforeSharpness: true,

    minTileContrast: 8,
    minSharpTileRatio: 0.55,
    minInformativeTiles: 4,
  );
  static const ImageQualityConfig photoCapture = ImageQualityConfig(
    blurThreshold: 200,
    minBrightness: 30,
    maxBrightness: 235,
    minContrast: 45,
  );

  static const ImageQualityConfig relaxed = ImageQualityConfig(
    blurThreshold: 50,
    minBrightness: 25,
    maxBrightness: 240,
    minContrast: 30,
    minSharpTileRatio: 0.40,
  );

  static const ImageQualityConfig strict = ImageQualityConfig(
    blurThreshold: 250,
    minBrightness: 50,
    maxBrightness: 200,
    minContrast: 65,
    minSharpTileRatio: 0.65,
  );

  /// Creates an [ImageQualityConfig] from a legacy threshold config.
  ///
  /// The parameter accepts [ImageQualityConfig] directly; `QualityConfig` is a
  /// backwards-compatible alias for the same type.
  factory ImageQualityConfig.fromQualityConfig(
    ImageQualityConfig config, {
    int maxAnalysisDimension = defaultMaxAnalysisDimension,
  }) =>
      config.copyWith(
        maxAnalysisDimension: maxAnalysisDimension,
      );

  ImageQualityConfig copyWith({
    double? blurThreshold,
    double? minBrightness,
    double? maxBrightness,
    double? minContrast,
    int? maxAnalysisDimension,
    bool? denoiseBeforeSharpness,
    int? tileRows,
    int? tileColumns,
    double? minTileContrast,
    int? minInformativeTiles,
    double? minSharpTileRatio,
    double? minTenengradScore,
  }) {
    return ImageQualityConfig(
      blurThreshold: blurThreshold ?? this.blurThreshold,
      minBrightness: minBrightness ?? this.minBrightness,
      maxBrightness: maxBrightness ?? this.maxBrightness,
      minContrast: minContrast ?? this.minContrast,
      maxAnalysisDimension: maxAnalysisDimension ?? this.maxAnalysisDimension,
      denoiseBeforeSharpness:
          denoiseBeforeSharpness ?? this.denoiseBeforeSharpness,
      tileRows: tileRows ?? this.tileRows,
      tileColumns: tileColumns ?? this.tileColumns,
      minTileContrast: minTileContrast ?? this.minTileContrast,
      minInformativeTiles: minInformativeTiles ?? this.minInformativeTiles,
      minSharpTileRatio: minSharpTileRatio ?? this.minSharpTileRatio,
      minTenengradScore: minTenengradScore ?? this.minTenengradScore,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'blurThreshold': blurThreshold,
      'minBrightness': minBrightness,
      'maxBrightness': maxBrightness,
      'minContrast': minContrast,
      'maxAnalysisDimension': maxAnalysisDimension,
      'denoiseBeforeSharpness': denoiseBeforeSharpness,
      'tileRows': tileRows,
      'tileColumns': tileColumns,
      'minTileContrast': minTileContrast,
      'minInformativeTiles': minInformativeTiles,
      'minSharpTileRatio': minSharpTileRatio,
      'minTenengradScore': minTenengradScore,
    };
  }

  factory ImageQualityConfig.fromMap(
    Map<Object?, Object?> map,
  ) {
    return ImageQualityConfig(
      blurThreshold: _asDouble(
        map['blurThreshold'],
        fallback: 100,
      ),
      minBrightness: _asDouble(
        map['minBrightness'],
        fallback: 40,
      ),
      maxBrightness: _asDouble(
        map['maxBrightness'],
        fallback: 220,
      ),
      minContrast: _asDouble(
        map['minContrast'],
        fallback: 50,
      ),
      maxAnalysisDimension: _asInt(
        map['maxAnalysisDimension'],
        fallback: defaultMaxAnalysisDimension,
      ),
      denoiseBeforeSharpness: _asBool(
        map['denoiseBeforeSharpness'],
        fallback: true,
      ),
      tileRows: _asInt(
        map['tileRows'],
        fallback: 4,
      ),
      tileColumns: _asInt(
        map['tileColumns'],
        fallback: 4,
      ),
      minTileContrast: _asDouble(
        map['minTileContrast'],
        fallback: 8,
      ),
      minInformativeTiles: _asInt(
        map['minInformativeTiles'],
        fallback: 4,
      ),
      minSharpTileRatio: _asDouble(
        map['minSharpTileRatio'],
        fallback: 0.5,
      ),
      minTenengradScore: _asDouble(
        map['minTenengradScore'],
        fallback: 0,
      ),
    );
  }

  @override
  String toString() {
    return 'ImageQualityConfig('
        'blurThreshold: $blurThreshold, '
        'brightness: $minBrightness-$maxBrightness, '
        'minContrast: $minContrast, '
        'maxAnalysisDimension: $maxAnalysisDimension, '
        'tiles: ${tileColumns}x$tileRows, '
        'minSharpTileRatio: $minSharpTileRatio'
        ')';
  }

  @override
  bool operator ==(Object other) {
    return other is ImageQualityConfig &&
        blurThreshold == other.blurThreshold &&
        minBrightness == other.minBrightness &&
        maxBrightness == other.maxBrightness &&
        minContrast == other.minContrast &&
        maxAnalysisDimension == other.maxAnalysisDimension &&
        denoiseBeforeSharpness == other.denoiseBeforeSharpness &&
        tileRows == other.tileRows &&
        tileColumns == other.tileColumns &&
        minTileContrast == other.minTileContrast &&
        minInformativeTiles == other.minInformativeTiles &&
        minSharpTileRatio == other.minSharpTileRatio &&
        minTenengradScore == other.minTenengradScore;
  }

  @override
  int get hashCode => Object.hash(
        blurThreshold,
        minBrightness,
        maxBrightness,
        minContrast,
        maxAnalysisDimension,
        denoiseBeforeSharpness,
        tileRows,
        tileColumns,
        minTileContrast,
        minInformativeTiles,
        minSharpTileRatio,
        minTenengradScore,
      );
}

double _asDouble(
  Object? value, {
  required double fallback,
}) {
  return value is num ? value.toDouble() : fallback;
}

int _asInt(
  Object? value, {
  required int fallback,
}) {
  return value is num ? value.toInt() : fallback;
}

bool _asBool(
  Object? value, {
  required bool fallback,
}) {
  return value is bool ? value : fallback;
}
