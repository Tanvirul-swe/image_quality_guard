## 1.1.0

### Sharpness

- Blur detection now scores the detailed regions of the image instead of the
  whole frame. The image is split into a 4x4 tile grid, near blank tiles are
  ignored, and the 80th percentile of the tile Laplacian variances becomes the
  new `ImageQualityResult.sharpnessScore`, which drives the blur decision.
  Smooth areas around the text of a card or page (table, plain card surface,
  portrait) no longer dilute the focus signal.
- **Recalibrate custom thresholds:** `sharpnessScore` is usually higher than
  the 1.0.0 `blurScore` for the same photo (for example about 1000 instead of
  about 390 for a sharp card on a table), so an unchanged `blurThreshold`
  accepts slightly softer images than before.
- Sharpness is always measured on at most 1280 px (the scale every
  `blurThreshold` is calibrated for), including with
  `ImageQualityConfig.fullResolution`. Brightness, contrast and glare still use
  the configured `maxAnalysisDimension`.
- New sharpness diagnostics on `ImageQualityResult`: `sharpnessScore`,
  `denoisedLaplacian`, `tenengradScore`, `lowTileSharpness`, `sharpTileRatio`,
  `sharpTilePercentage`, `informativeTileCount`, `totalTileCount`,
  `hasTileSharpnessData`, `isOutOfFocus` and `hasLowSharpCoverage`.
  `blurScore` keeps the raw whole-image Laplacian variance of previous versions.
- New optional sharpness settings on `ImageQualityConfig`:
  `denoiseBeforeSharpness`, `tileRows`, `tileColumns`, `minTileContrast`,
  `minInformativeTiles`, `minSharpTileRatio` and `minTenengradScore`. All of
  them are off or neutral by default.

### Glare

- New glare check: `ImageQualityResult.glareRatio` is the fraction of blown out
  pixels (luminance >= 250), `hasGlare` compares it with the new
  `ImageQualityConfig.maxGlareRatio`. Reflections on laminated cards are now
  reported even when the average brightness looks normal. Disabled (`1.0`) by
  default.

### Presets

- New `ImageQualityConfig.nidCapture` preset for national ID card capture.
- `cardScanning`, `documentScanning` and `nidCapture` reject images with more
  than 3% blown out pixels.
- `documentScanning`: `maxBrightness` 215 -> 235 and `minContrast` 55 -> 30,
  because a well exposed white page has a high average brightness and a low
  standard deviation; it now also requires 55% of the informative tiles to be
  sharp, so the page must fill most of the frame.
- `strict` requires 65% of the informative tiles to be sharp.

### Other

- `QualityConfig` is now a type alias of `ImageQualityConfig`; existing code
  using `QualityConfig` keeps compiling.
- Issues now distinguish an out of focus image from one where too little of
  the frame is sharp.
- The example app shows glare and sharp area results, adds the NID Capture
  profile and explains which profile fits ID cards.

## 1.0.0

- Added combined blur, brightness, and contrast validation.
- Added individual analyzers for each image quality metric.
- Added configurable thresholds and five ready-to-use presets.
- Added validation for encoded bytes and decoded image objects.
- Added typed result models with summaries and issue reporting.
- Added an interactive Flutter example with camera, gallery, and custom inputs.
