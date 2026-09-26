import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/contrast_result.dart';
import '../processing/luminance_extractor.dart';
import 'contrast_detector.dart';

/// Analyzes image contrast using the standard deviation of pixel luminance.
///
/// Images with a low standard deviation have poor contrast (flat histogram),
/// while a high standard deviation indicates good contrast (wide histogram
/// spread).
///
/// The actual measurement is implemented by [ContrastDetector], which also runs
/// inside the background processing isolate of `ImageQualityGuard.analyze`.
class ContrastAnalyzer {
  /// Minimum acceptable contrast score (standard deviation).
  /// Images below this value are considered low contrast.
  final double minContrast;

  /// Creates a [ContrastAnalyzer] with the given threshold.
  ///
  /// The [minContrast] value represents the minimum standard deviation
  /// of pixel luminance values for acceptable contrast. Default is 50.0.
  const ContrastAnalyzer({this.minContrast = 50.0})
      : assert(minContrast >= 0, 'minContrast must be non-negative');

  /// Analyzes contrast of an image from raw bytes.
  ///
  /// Decoding happens on the calling isolate. Returns a [ContrastResult]
  /// containing the contrast analysis.
  /// Throws an [ArgumentError] if the image cannot be decoded.
  ContrastResult analyze(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      throw ArgumentError('Cannot decode image from provided bytes');
    }
    return analyzeFromImage(image);
  }

  /// Analyzes contrast of an already decoded image.
  ///
  /// The image is not modified. Returns a [ContrastResult] containing the
  /// contrast analysis.
  ContrastResult analyzeFromImage(img.Image image) => classify(
        ContrastDetector.standardDeviationOf(
            LuminanceExtractor.fromImage(image)),
      );

  /// Classifies an already measured [contrastScore].
  ContrastResult classify(double contrastScore) =>
      ContrastDetector(minContrast: minContrast).classify(contrastScore);
}
