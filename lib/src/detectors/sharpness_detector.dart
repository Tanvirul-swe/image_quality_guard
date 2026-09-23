import 'dart:typed_data';

import '../models/sharpness_result.dart';
import '../processing/gaussian_smoother.dart';
import '../processing/luminance_statistics.dart';
import 'blur_detector.dart';
import 'tenengrad_detector.dart';

abstract final class SharpnessDetector {
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
    if (width < 3 ||
        height < 3 ||
        luminance.length < width * height) {
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

    final medianSharpness = informativeTileCount == 0
        ? denoisedLaplacian
        : _median(tileScores);

    final lowTileSharpness = informativeTileCount == 0
        ? denoisedLaplacian
        : _percentile(tileScores, 0.25);

    final sharpTileRatio = informativeTileCount == 0
        ? 0.0
        : sharpTiles / informativeTileCount;

    // If enough useful tiles exist, prefer the median tile score.
    //
    // This prevents one sharp card border or noisy section from making
    // the entire image appear sharp.
    final robustSharpnessScore =
        informativeTileCount >= minInformativeTiles
            ? medianSharpness
            : denoisedLaplacian;

    // =========================================================
    // 6. Final decision
    // =========================================================

    final sharpnessFailed =
        robustSharpnessScore < blurThreshold;

    final tileCoverageFailed =
        informativeTileCount >= minInformativeTiles &&
        sharpTileRatio < minSharpTileRatio;

    final tenengradFailed =
        minTenengradScore > 0 &&
        tenengrad < minTenengradScore;

    final isBlurry =
        sharpnessFailed ||
        tileCoverageFailed ||
        tenengradFailed;

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

        final response =
            4.0 * luminance[index] -
            luminance[index - 1] -
            luminance[index + 1] -
            luminance[index - width] -
            luminance[index + width];

        statistics.add(response);
      }
    }

    return statistics.variance;
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;

    final middle = values.length ~/ 2;

    if (values.length.isOdd) {
      return values[middle];
    }

    return (values[middle - 1] + values[middle]) / 2;
  }

  static double _percentile(
    List<double> values,
    double percentile,
  ) {
    if (values.isEmpty) return 0;

    final normalized = percentile.clamp(0.0, 1.0);

    final index =
        ((values.length - 1) * normalized).round();

    return values[index];
  }
}