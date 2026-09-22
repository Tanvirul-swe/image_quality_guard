# Image Quality Guard

Detect blurry, poorly lit, and low-contrast images before they enter your
upload, scanning, or recognition workflow.

`image_quality_guard` is a platform-independent Dart package designed for
Flutter and Dart applications. It analyzes image bytes without native runtime
dependencies and provides both a combined validator and individual checks.

## Features

- Blur detection using Laplacian variance
- Brightness classification as too dark, optimal, or too bright
- Contrast measurement using luminance standard deviation
- One-call validation with a combined pass/fail result
- Presets for cards, documents, photos, relaxed checks, and strict checks
- Custom thresholds for application-specific quality requirements
- Support for encoded image bytes and decoded `image` package objects

## Installation

Add the package to your Flutter project:

```console
flutter pub add image_quality_guard
```

Then import it:

```dart
import 'package:image_quality_guard/image_quality_guard.dart';
```

## Quick start

Pass encoded image bytes from a camera, gallery picker, file, or network
response to `ImageQualityValidator`:

```dart
final validator = ImageQualityValidator();
final result = await validator.validate(imageBytes);

if (result.isValid) {
  // Continue with the upload or recognition flow.
} else {
  print(result.issues);
}
```

Invalid or unsupported image bytes throw an `ArgumentError`.

## Presets

Select a preset that matches the capture flow:

```dart
final validator = ImageQualityValidator(
  config: QualityConfig.documentScanning,
);

final result = await validator.validate(imageBytes);
```

| Preset | Intended use |
| --- | --- |
| `QualityConfig.cardScanning` | IDs, bank cards, and licenses |
| `QualityConfig.documentScanning` | Forms, receipts, and printed text |
| `QualityConfig.photoCapture` | Higher-quality photo capture |
| `QualityConfig.relaxed` | Challenging lighting or lower-quality cameras |
| `QualityConfig.strict` | Workflows with higher quality requirements |

## Custom thresholds

```dart
final validator = ImageQualityValidator(
  config: const QualityConfig(
    blurThreshold: 150,
    minBrightness: 50,
    maxBrightness: 210,
    minContrast: 60,
  ),
);
```

- A higher `blurThreshold` requires a sharper image.
- Brightness uses a `0` to `255` luminance scale.
- A higher `minContrast` requires more luminance variation.

Quality thresholds are heuristics. Calibrate them with representative images
from the devices and environments used by your application.

## Individual checks

The validator can run one check at a time when a combined result is not needed:

```dart
final validator = ImageQualityValidator();

final blur = validator.checkBlur(imageBytes);
final brightness = validator.checkBrightness(imageBytes);
final contrast = validator.checkContrast(imageBytes);

print(blur.variance);
print(brightness.averageBrightness);
print(contrast.contrastScore);
```

For an image already decoded with the `image` package, use
`validateFromImage`, `checkBlurFromImage`, `checkBrightnessFromImage`, or
`checkContrastFromImage` to avoid decoding it again.

## Result data

`QualityResult` exposes:

- `isValid`: whether every quality check passed
- `issues`: all detected quality issues
- `errorMessage`: the first issue, or `null` when valid
- `blurResult`: variance, confidence, threshold, and blur status
- `brightnessResult`: average brightness, thresholds, and classification
- `contrastResult`: contrast score, threshold, and pass status

## Example

The included Flutter example provides camera and gallery input, every preset,
custom threshold sliders, image preview, and a focused results view. Run it
from the package root with:

```console
cd example
flutter run
```

## Performance

Analysis is performed locally and synchronously after image decoding. Very
large images can take noticeable time, so resize camera images or run analysis
in an isolate when smooth UI responsiveness is critical.

## License

This package is available under the BSD 3-Clause License. See [LICENSE](LICENSE).
