class SharpnessResult {
  const SharpnessResult({
    required this.isBlurry,
    required this.rawLaplacianVariance,
    required this.denoisedLaplacianVariance,
    required this.sharpnessScore,
    required this.tenengradScore,
    required this.lowTileSharpness,
    required this.sharpTileRatio,
    required this.informativeTileCount,
    required this.totalTileCount,
  });

  /// Laplacian calculated from the original luminance buffer.
  ///
  /// Useful for backwards compatibility and debugging.
  final double rawLaplacianVariance;

  /// Whole-image Laplacian after Gaussian smoothing.
  final double denoisedLaplacianVariance;

  /// Robust score used for blur classification.
  ///
  /// Normally this is the median Laplacian variance of informative tiles.
  final double sharpnessScore;

  /// Sobel/Tenengrad sharpness score.
  final double tenengradScore;

  /// 25th percentile sharpness of informative tiles.
  final double lowTileSharpness;

  /// Percentage of informative tiles that meet the configured sharpness
  /// threshold.
  ///
  /// Range: 0.0 - 1.0.
  final double sharpTileRatio;

  final int informativeTileCount;

  final int totalTileCount;

  final bool isBlurry;

  @override
  String toString() {
    return 'SharpnessResult('
        'isBlurry: $isBlurry, '
        'rawLaplacian: ${rawLaplacianVariance.toStringAsFixed(2)}, '
        'denoisedLaplacian: ${denoisedLaplacianVariance.toStringAsFixed(2)}, '
        'sharpnessScore: ${sharpnessScore.toStringAsFixed(2)}, '
        'tenengrad: ${tenengradScore.toStringAsFixed(2)}, '
        'sharpTileRatio: ${sharpTileRatio.toStringAsFixed(2)}, '
        'informativeTiles: $informativeTileCount/$totalTileCount'
        ')';
  }
}
