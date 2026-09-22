/// Category of an [ImageQualityException].
///
/// The category is transported as a plain [String] when an error crosses an
/// isolate boundary, so it is also used to rebuild the matching exception
/// subclass on the main isolate.
enum ImageQualityErrorType {
  /// The supplied bytes are not a valid, supported or complete image.
  decode,

  /// The image was decoded but the analysis could not be completed.
  analysis,

  /// The background isolate could not be started or did not answer.
  isolate,
}

/// Base class for every error reported by `image_quality_guard`.
///
/// Errors never carry objects that cannot cross an isolate boundary: [message]
/// and [cause] are plain strings, which means the same instance shape can be
/// produced inside the processing isolate and rebuilt on the main isolate.
///
/// ```dart
/// try {
///   final result = await ImageQualityGuard.analyze(imageBytes);
/// } on ImageDecodeException catch (error) {
///   // Unsupported or corrupted file.
/// } on ImageQualityException catch (error) {
///   // Any other failure, the app keeps running.
/// }
/// ```
class ImageQualityException implements Exception {
  /// Creates an exception with a human readable [message].
  const ImageQualityException(
    this.message, {
    this.type = ImageQualityErrorType.analysis,
    this.cause,
  });

  /// Human readable description of the failure.
  final String message;

  /// Machine readable category of the failure.
  final ImageQualityErrorType type;

  /// Stringified underlying error or stack trace, when available.
  ///
  /// Kept as a [String] so the exception stays isolate-safe.
  final String? cause;

  /// Rebuilds the concrete exception subclass that matches [type].
  ///
  /// Used by the main isolate to restore a typed exception that was produced
  /// from a serialized failure response.
  static ImageQualityException fromType(
    ImageQualityErrorType type,
    String message, {
    String? cause,
  }) {
    switch (type) {
      case ImageQualityErrorType.decode:
        return ImageDecodeException(message: message, cause: cause);
      case ImageQualityErrorType.analysis:
        return ImageAnalysisException(message: message, cause: cause);
      case ImageQualityErrorType.isolate:
        return ImageIsolateException(message: message, cause: cause);
    }
  }

  @override
  String toString() {
    final details = cause;
    if (details == null || details.isEmpty) {
      return '$runtimeType: $message';
    }
    return '$runtimeType: $message\nCaused by: $details';
  }
}

/// Thrown when the provided bytes cannot be decoded into an image.
///
/// Typical causes are an empty buffer, a truncated upload or a file format that
/// the `image` package cannot read.
class ImageDecodeException extends ImageQualityException {
  /// Creates a decode failure with an optional underlying [cause].
  const ImageDecodeException({
    String message = 'Cannot decode image from provided bytes',
    String? cause,
  }) : super(
          message,
          type: ImageQualityErrorType.decode,
          cause: cause,
        );
}

/// Thrown when the decoded image cannot be analyzed.
///
/// The severity of the metrics is reported through `issues` on the result
/// object, not through this exception. This type only signals unexpected
/// processing failures.
class ImageAnalysisException extends ImageQualityException {
  /// Creates an analysis failure with an optional underlying [cause].
  const ImageAnalysisException({
    String message = 'The image could not be analyzed',
    String? cause,
  }) : super(
          message,
          type: ImageQualityErrorType.analysis,
          cause: cause,
        );
}

/// Thrown when the background isolate cannot be used for the analysis.
///
/// The recommended API never requires callers to manage isolates; this error
/// only surfaces when the runtime refuses to start one.
class ImageIsolateException extends ImageQualityException {
  /// Creates an isolate failure with an optional underlying [cause].
  const ImageIsolateException({
    String message = 'Image quality analysis could not run in the background',
    String? cause,
  }) : super(
          message,
          type: ImageQualityErrorType.isolate,
          cause: cause,
        );
}
