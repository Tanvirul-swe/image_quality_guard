import 'dart:math' as math;
import 'dart:typed_data';

/// Incremental mean and variance calculated with Welford's online algorithm.
///
/// Image analysis needs a mean and a variance over millions of samples. Keeping
/// every sample in a `List<double>` would allocate tens of megabytes for a
/// single camera photo, so instead the statistics are folded into the running
/// values below: memory stays constant and the result is numerically stable.
///
/// ```dart
/// final statistics = RunningStatistics();
/// for (final value in samples) {
///   statistics.add(value);
/// }
/// print(statistics.mean);
/// print(statistics.standardDeviation);
/// ```
class RunningStatistics {
  int _count = 0;
  double _mean = 0;
  double _sumOfSquaredDeviations = 0;

  /// Number of samples added so far.
  int get count => _count;

  /// Running mean of the added samples, or `0` when no sample was added.
  double get mean => _count == 0 ? 0 : _mean;

  /// Population variance of the added samples.
  double get variance => _count == 0 ? 0 : _sumOfSquaredDeviations / _count;

  /// Population standard deviation of the added samples.
  double get standardDeviation => _count == 0 ? 0 : math.sqrt(variance);

  /// Folds a single [value] into the running statistics.
  void add(double value) {
    _count++;
    final delta = value - _mean;
    _mean += delta / _count;
    // The second delta uses the updated mean, which is what makes Welford's
    // algorithm stable for large sample counts.
    _sumOfSquaredDeviations += delta * (value - _mean);
  }

  @override
  String toString() => 'RunningStatistics(count: $_count, '
      'mean: ${mean.toStringAsFixed(2)}, '
      'variance: ${variance.toStringAsFixed(2)})';
}

/// Calculates mean and standard deviation over the luminance [samples] in a
/// single pass.
///
/// Used for the brightness (mean) and contrast (standard deviation) metrics so
/// both are derived from the same traversal of the image.
RunningStatistics summarizeLuminance(Uint8List samples) {
  final statistics = RunningStatistics();
  for (var index = 0; index < samples.length; index++) {
    statistics.add(samples[index].toDouble());
  }
  return statistics;
}
