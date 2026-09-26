import 'dart:typed_data';

import '../models/sharpness_result.dart';
import '../processing/gaussian_smoother.dart';
import '../processing/luminance_statistics.dart';
import 'blur_detector.dart';
import 'tenengrad_detector.dart';

abstract final class SharpnessDetector {
  /// Percentile of the informative tile scores used as the sharpness score.
  ///
  /// A median would treat every informative tile as equally important, but in
  /// a card or document photo most tiles show plain card surface, a portrait
  /// or the table behind the card - areas that are legitimately smooth even
  /// when the photo is perfectly focused. Only the tiles that hold text and
  /// fine print carry the focus signal, so the score follows the upper tiles.
  /// With the default 4x4 grid the 80th percentile needs about four sharp
  /// tiles, so a single noisy or high-contrast tile cannot pass a blurry image.
  static const double sharpnessPercentile = 0.80;

  static SharpnessResult analyze(
    Uint8List luminance, {
    required int width,
    required int height,
    required double blurThreshold,
    required bool denoise,
    required int tileRows,
    required int tileColumns,
    required double minTileContrast,
    required int minInformativeTiles,
    required double minSharpTileRatio,
    required double minTenengradScore,
  }) {
    if (width < 3 || height < 3 || luminance.length < width * height) {
      return const SharpnessResult(
        isBlurry: true,
        rawLaplacianVariance: 0,
        denoisedLaplacianVariance: 0,
        sharpnessScore: 0,
        tenengradScore: 0,
        lowTileSharpness: 0,
        sharpTileRatio: 0,
        informativeTileCount: 0,
        totalTileCount: 0,
      );
    }

    // =========================================================
    // 1. Preserve raw Laplacian for debugging/backwards support
    // =========================================================

    final rawLaplacian = BlurDetector.laplacianVariance(
      luminance,
      width: width,
      height: height,
    );

    // =========================================================
    // 2. Remove camera/JPEG noise before sharpness measurement
    // =========================================================

    final processed = denoise
        ? GaussianSmoother.apply3x3(
            luminance,
            width: width,
            height: height,
          )
        : luminance;

    final denoisedLaplacian = BlurDetector.laplacianVariance(
      processed,
      width: width,
      height: height,
    );

    // =========================================================
    // 3. Independent Sobel/Tenengrad metric
    // =========================================================

    final tenengrad = TenengradDetector.score(
      processed,
      width: width,
      height: height,
    );

    // =========================================================
    // 4. Tile analysis
    // =========================================================

    final tileScores = <double>[];

    var sharpTiles = 0;
    var totalTiles = 0;

    final rows = tileRows <= 0 ? 1 : tileRows;
    final columns = tileColumns <= 0 ? 1 : tileColumns;

    for (var row = 0; row < rows; row++) {
      final yStart = (row * height) ~/ rows;
      final yEnd = ((row + 1) * height) ~/ rows;

      for (var column = 0; column < columns; column++) {
        final xStart = (column * width) ~/ columns;
        final xEnd = ((column + 1) * width) ~/ columns;

        if ((xEnd - xStart) < 3 || (yEnd - yStart) < 3) {
          continue;
        }

        totalTiles++;

        final tileContrast = _regionContrast(
          processed,
          width: width,
          xStart: xStart,
          xEnd: xEnd,
          yStart: yStart,
          yEnd: yEnd,
        );

        // Ignore tiles that contain almost no information.
        //
        // Example:
        // - blank white card area
        // - plain wall
        // - empty background
        if (tileContrast < minTileContrast) {
          continue;
        }

        final tileSharpness = _regionLaplacianVariance(
          processed,
          width: width,
          xStart: xStart,
          xEnd: xEnd,
          yStart: yStart,
          yEnd: yEnd,
        );

        tileScores.add(tileSharpness);

        if (tileSharpness >= blurThreshold) {
          sharpTiles++;
        }
      }
    }

    // =========================================================
    // 5. Robust statistics
    // =========================================================

    tileScores.sort();

    final informativeTileCount = tileScores.length;

    final upperTileSharpness = informativeTileCount == 0
        ? denoisedLaplacian
        : _percentile(tileScores, sharpnessPercentile);

    final lowTileSharpness = informativeTileCount == 0
        ? denoisedLaplacian
        : _percentile(tileScores, 0.25);

    final sharpTileRatio =
        informativeTileCount == 0 ? 0.0 : sharpTiles / informativeTileCount;

    // If enough useful tiles exist, score the detailed regions of the image
    // (see [sharpnessPercentile]) instead of averaging them with smooth areas.
    final robustSharpnessScore = informativeTileCount >= minInformativeTiles
        ? upperTileSharpness
        : denoisedLaplacian;

    // =========================================================
    // 6. Final decision
    // =========================================================

    final sharpnessFailed = robustSharpnessScore < blurThreshold;

    final tileCoverageFailed = informativeTileCount >= minInformativeTiles &&
        sharpTileRatio < minSharpTileRatio;

    final tenengradFailed =
        minTenengradScore > 0 && tenengrad < minTenengradScore;

    final isBlurry = sharpnessFailed || tileCoverageFailed || tenengradFailed;

    return SharpnessResult(
      isBlurry: isBlurry,
      rawLaplacianVariance: rawLaplacian,
      denoisedLaplacianVariance: denoisedLaplacian,
      sharpnessScore: robustSharpnessScore,
      tenengradScore: tenengrad,
      lowTileSharpness: lowTileSharpness,
      sharpTileRatio: sharpTileRatio,
      informativeTileCount: informativeTileCount,
      totalTileCount: totalTiles,
    );
  }

  static double _regionContrast(
    Uint8List luminance, {
    required int width,
    required int xStart,
    required int xEnd,
    required int yStart,
    required int yEnd,
  }) {
    final statistics = RunningStatistics();

    for (var y = yStart; y < yEnd; y++) {
      final row = y * width;

      for (var x = xStart; x < xEnd; x++) {
        statistics.add(
          luminance[row + x].toDouble(),
        );
      }
    }

    return statistics.standardDeviation;
  }

  static double _regionLaplacianVariance(
    Uint8List luminance, {
    required int width,
    required int xStart,
    required int xEnd,
    required int yStart,
    required int yEnd,
  }) {
    final statistics = RunningStatistics();

    // Skip tile-local borders.
    for (var y = yStart + 1; y < yEnd - 1; y++) {
      final row = y * width;

      for (var x = xStart + 1; x < xEnd - 1; x++) {
        final index = row + x;

        final response = 4.0 * luminance[index] -
            luminance[index - 1] -
            luminance[index + 1] -
            luminance[index - width] -
            luminance[index + width];

        statistics.add(response);
      }
    }

    return statistics.variance;
  }

  static double _percentile(
    List<double> values,
    double percentile,
  ) {
    if (values.isEmpty) return 0;

    final normalized = percentile.clamp(0.0, 1.0);

    final index = ((values.length - 1) * normalized).round();

    return values[index];
  }
}
