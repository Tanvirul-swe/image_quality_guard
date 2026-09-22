import 'dart:typed_data';

import '../config/image_quality_config.dart';
import '../models/image_quality_exception.dart';
import '../models/image_quality_result.dart';
import 'image_processor.dart';

/// Key of the encoded image bytes in a job payload.
const String payloadBytesKey = 'bytes';

/// Key of the serialized [ImageQualityConfig] in a job payload.
const String payloadConfigKey = 'config';

/// Key of the status code in a job response.
const String responseStatusKey = 'status';

/// Key of the serialized [ImageQualityResult] in a successful job response.
const String responseResultKey = 'result';

/// Key of the [ImageQualityErrorType] name in a failed job response.
const String responseErrorTypeKey = 'errorType';

/// Key of the human readable error message in a failed job response.
const String responseMessageKey = 'message';

/// Key of the stringified underlying error in a failed job response.
const String responseCauseKey = 'cause';

/// Status code of a successful job response.
const String jobStatusSuccess = 'ok';

/// Status code of a failed job response.
const String jobStatusFailure = 'failure';

/// Builds the payload handed to the processing isolate.
///
/// The payload contains only isolate safe values: a [Uint8List] of encoded
/// image bytes and a map of primitives describing the configuration. No custom
/// object and no decoded image crosses the isolate boundary.
Map<String, dynamic> buildImageQualityPayload(
  Uint8List imageBytes,
  ImageQualityConfig config,
) =>
    <String, dynamic>{
      payloadBytesKey: imageBytes,
      payloadConfigKey: config.toMap(),
    };

/// Runs the complete image quality pipeline for a [payload].
///
/// This is the entry point executed inside the background isolate. It never
/// throws: failures are converted into a serializable response map so that the
/// main isolate can rebuild a typed [ImageQualityException] without relying on
/// error propagation across isolates.
Map<String, dynamic> runImageQualityJob(Map<String, dynamic> payload) {
  try {
    final imageBytes = payload[payloadBytesKey];
    if (imageBytes is! Uint8List) {
      throw const ImageQualityException(
        'Job payload does not contain image bytes',
        type: ImageQualityErrorType.analysis,
      );
    }

    final rawConfig = payload[payloadConfigKey];
    final config = rawConfig is Map
        ? ImageQualityConfig.fromMap(rawConfig)
        : const ImageQualityConfig();

    final result = ImageProcessor.processBytes(imageBytes, config: config);

    return <String, dynamic>{
      responseStatusKey: jobStatusSuccess,
      responseResultKey: result.toMap(),
    };
  } on ImageQualityException catch (error) {
    return _failure(error.type, error.message, error.cause);
  } on Object catch (error, stackTrace) {
    // Last line of defence: an unexpected failure must not escape the isolate,
    // because a non sendable error object would surface as a RemoteError on the
    // main isolate.
    return _failure(
      ImageQualityErrorType.analysis,
      'Unexpected error while analyzing the image',
      '$error\n$stackTrace',
    );
  }
}

/// Rebuilds an [ImageQualityResult] from a [runImageQualityJob] response.
///
/// Throws the typed exception matching the failure reported by the isolate.
ImageQualityResult decodeImageQualityResponse(Map<String, dynamic> response) {
  if (response[responseStatusKey] == jobStatusSuccess) {
    final rawResult = response[responseResultKey];
    if (rawResult is Map) {
      return ImageQualityResult.fromMap(rawResult);
    }
    throw const ImageAnalysisException(
      message: 'The image analysis did not return a result',
    );
  }

  final rawType = response[responseErrorTypeKey];
  final type = ImageQualityErrorType.values.firstWhere(
    (value) => value.name == rawType,
    orElse: () => ImageQualityErrorType.analysis,
  );
  final message = response[responseMessageKey];
  final cause = response[responseCauseKey];

  throw ImageQualityException.fromType(
    type,
    message is String ? message : 'Image quality analysis failed',
    cause: cause is String ? cause : null,
  );
}

/// Builds a serializable failure response.
Map<String, dynamic> _failure(
  ImageQualityErrorType type,
  String message,
  String? cause,
) =>
    <String, dynamic>{
      responseStatusKey: jobStatusFailure,
      responseErrorTypeKey: type.name,
      responseMessageKey: message,
      responseCauseKey: cause,
    };
