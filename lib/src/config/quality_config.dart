import 'image_quality_config.dart';

/// Backwards-compatible name for [ImageQualityConfig].
///
/// New code can import and use [ImageQualityConfig] directly. This alias keeps
/// existing `QualityConfig` imports and constructor calls working without a
/// second configuration implementation.
typedef QualityConfig = ImageQualityConfig;
