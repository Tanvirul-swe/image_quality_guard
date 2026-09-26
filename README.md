<p align="center">
  <img src="asset/logo.png" alt="Image Quality Guard" width="120" />
</p>

<p align="center">
  <b>Image Quality Guard</b><br>
  Detect blurry, glare-affected, poorly lit, and low-contrast images before they enter your upload, scanning, or recognition workflow.
</p>

<p align="center">
  <a href="https://pub.dev/packages/image_quality_guard">
    <img src="https://img.shields.io/pub/v/image_quality_guard.svg?color=blue&label=pub.dev" alt="pub.dev version">
  </a>
  <a href="https://github.com/Tanvirul-swe/image_quality_guard">
    <img src="https://img.shields.io/github/stars/Tanvirul-swe/image_quality_guard.svg?color=blue&label=stars" alt="GitHub stars">
  </a>
  <a href="https://Tanvirul-swe.github.io/image_quality_guard/">
    <img src="https://img.shields.io/badge/Web%20Demo-%F0%9F%8C%90-blue" alt="Web Demo">
  </a>
  <img src="https://img.shields.io/badge/Flutter-%2302569B.svg?alt=Flutter&color=blue" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-%230175C2.svg?alt=Dart&color=blue" alt="Dart">
</p>

---

## 🎯 What is Image Quality Guard?

`image_quality_guard` is a platform-independent Dart package for **Flutter** and **Dart** applications. It analyzes image bytes to detect quality issues — blur, glare, brightness, and contrast — before images enter your upload, scanning, or recognition pipeline.

**No native runtime dependencies.** Analysis runs entirely in Dart, with optional background isolate support for smooth UI performance.

### 🔑 Key Capabilities

| Capability | Description |
|---|---|
| 🔍 **Blur Detection** | Tile-based Laplacian variance that scores the detailed regions (text, print) of the image |
| ✨ **Glare Detection** | Flags blown-out reflections, e.g. on laminated ID cards |
| 💡 **Brightness Analysis** | Classifies images as too dark, optimal, or too bright |
| 🎨 **Contrast Measurement** | Luminance standard deviation for depth and clarity |
| ✅ **One-Call Validation** | Combined pass/fail with a single `analyze()` call |
| ⚙️ **8 Presets** | Mobile, card, NID, document, photo, relaxed, strict, and full-resolution configurations |
| 🎛️ **Custom Thresholds** | Fine-tune every metric for your specific use case |
| 🚀 **Background Isolate** | Non-blocking analysis for large images |
| 🌐 **Web Support** | Runs on Flutter web — desktop, mobile, and browser |
| 📦 **Encoded & Decoded Input** | Accept raw bytes or pre-decoded `image` package objects |

---

## 📦 Installation

```console
flutter pub add image_quality_guard
```

```dart
import 'package:image_quality_guard/image_quality_guard.dart';
```

---

## 🚀 Quick Start

### Main API: `ImageQualityGuard` (recommended)

Pass encoded image bytes from a camera, gallery picker, file, or network response. Analysis runs on a **background isolate** — your UI stays responsive:

```dart
import 'dart:typed_data';
import 'package:image_quality_guard/image_quality_guard.dart';

final result = await ImageQualityGuard.analyze(imageBytes);

if (result.isValid) {
  // ✅ Image quality is acceptable — proceed with upload or processing
} else {
  // ❌ Issues detected
  for (final issue in result.issues) {
    print(issue);
  }
}
```

> ⚠️ Invalid or unsupported image bytes throw an `ImageDecodeException`.

---

### Alternative API: `ImageQualityValidator`

A convenience wrapper that returns `QualityResult` with typed sub-results:

```dart
final validator = ImageQualityValidator();
final result = await validator.validate(imageBytes);

if (result.isValid) {
  // Proceed with the upload or recognition flow.
} else {
  print(result.errorMessage);
}
```

---

## 🏷️ Presets

Choose a preset matching your capture scenario:

```dart
final result = await ImageQualityGuard.analyze(
  imageBytes,
  config: ImageQualityConfig.nidCapture,
);
```

| Preset | Intended Use | Blur | Min Bright | Max Bright | Min Contrast | Max Glare |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 🪪 `ImageQualityConfig.cardScanning` | IDs, bank cards, licenses | 80 | 35 | 230 | 40 | 3% |
| 🆔 `ImageQualityConfig.nidCapture` | National ID cards (calibrate on your devices) | 80 | 55 | 225 | 25 | 3% |
| 📄 `ImageQualityConfig.documentScanning` | Forms, receipts, printed text | 120 | 45 | 235 | 30 | 3% |
| 📷 `ImageQualityConfig.photoCapture` | High-quality photo capture | 200 | 30 | 235 | 45 | off |
| 😊 `ImageQualityConfig.relaxed` | Challenging lighting / low-quality cameras | 50 | 25 | 240 | 30 | off |
| ✔️ `ImageQualityConfig.strict` | Strict quality requirements | 250 | 50 | 200 | 65 | off |
| 📱 `ImageQualityConfig.mobile` | Balanced defaults for everyday images | 100 | 40 | 220 | 50 | off |
| 🖼️ `ImageQualityConfig.fullResolution` | `mobile` thresholds, brightness/contrast/glare on every pixel | 100 | 40 | 220 | 50 | off |

`documentScanning` also requires 55% (and `strict` 65%) of the detailed image tiles to be sharp, so the page must fill most of the frame. Use `cardScanning` or `nidCapture` for ID cards photographed on a table.

---

## 🎛️ Custom Thresholds

Override individual metrics for application-specific needs:

```dart
final result = await ImageQualityGuard.analyze(
  imageBytes,
  config: const ImageQualityConfig(
    blurThreshold: 150,
    minBrightness: 50,
    maxBrightness: 210,
    minContrast: 60,
    maxGlareRatio: 0.03,
  ),
);
```

| Parameter | Description | Range | Default |
|---|---|:---:|:---:|
| `blurThreshold` | Minimum `sharpnessScore`; higher = sharper image required | 1–∞ | 100.0 |
| `minBrightness` | Below = too dark (0–255 luminance) | 0–255 | 40.0 |
| `maxBrightness` | Above = too bright/overexposed (0–255) | 0–255 | 220.0 |
| `minContrast` | Higher = more luminance variation required | 0–∞ | 50.0 |
| `maxGlareRatio` | Max fraction of blown-out pixels (luminance ≥ 250); `1.0` = off | 0–1 | 1.0 |
| `maxAnalysisDimension` | Longest side for brightness/contrast/glare (px); `0` = full res. Sharpness is always measured at ≤ 1280 px, the scale `blurThreshold` is calibrated for | 0–∞ | 1280 |

#### Advanced sharpness settings

| Parameter | Description | Default |
|---|---|:---:|
| `tileRows` / `tileColumns` | Grid used for tile-based sharpness | 4 × 4 |
| `minTileContrast` | Tiles with a lower luminance std. deviation are ignored as blank | 8.0 |
| `minInformativeTiles` | Fewer informative tiles → whole-image Laplacian is used instead | 4 |
| `minSharpTileRatio` | Minimum share of informative tiles that must reach `blurThreshold`; `0` = off | 0.0 |
| `minTenengradScore` | Optional Sobel/Tenengrad edge-strength gate; `0` = off | 0.0 |
| `denoiseBeforeSharpness` | 3×3 Gaussian smoothing before measuring; lowers scores ~5–10×, so lower `blurThreshold` too | false |

> 💡 **Tip:** Quality thresholds are heuristics. Calibrate them with representative images from your target devices and environments.

---

## 🔎 Individual Checks

Run specific checks independently:

```dart
final validator = ImageQualityValidator();

// 🔍 Blur check
final blur = validator.checkBlur(imageBytes);
print('Variance: ${blur.variance}, Sharp: ${!blur.isBlurry}');

// 💡 Brightness check
final brightness = validator.checkBrightness(imageBytes);
print('Level: ${brightness.level}, Avg: ${brightness.averageBrightness}');

// 🎨 Contrast check
final contrast = validator.checkContrast(imageBytes);
print('Score: ${contrast.contrastScore}, Good: ${contrast.hasGoodContrast}');
```

> The individual checks measure the classic whole-image Laplacian variance. `ImageQualityGuard.analyze()` uses the tile-based `sharpnessScore` described below.

For images already decoded with `package:image`, use the `*FromImage` variants to avoid re-decoding:

```dart
final blur = validator.checkBlurFromImage(decodedImage);
final brightness = validator.checkBrightnessFromImage(decodedImage);
final contrast = validator.checkContrastFromImage(decodedImage);
```

---

## 📊 Result Data

### `ImageQualityResult` (from `ImageQualityGuard`)

| Property | Type | Description |
|---|---|---|
| `isValid` | `bool` | All checks passed |
| `sharpnessScore` | `double` | Tile-based sharpness used for the blur decision (higher = sharper) |
| `isBlurry` | `bool` | `isOutOfFocus` or `hasLowSharpCoverage` |
| `isOutOfFocus` | `bool` | `sharpnessScore` (or the optional Tenengrad gate) is below the threshold |
| `hasLowSharpCoverage` | `bool` | Too few tiles are sharp (`minSharpTileRatio`) — usually the subject does not fill the frame |
| `sharpTileRatio` | `double` | Share of informative tiles reaching `blurThreshold` (0–1) |
| `blurScore` | `double` | Raw whole-image Laplacian variance (legacy, diagnostic) |
| `tenengradScore` | `double` | Sobel gradient edge strength (diagnostic) |
| `brightness` | `double` | Average luminance (0–255) |
| `contrast` | `double` | Luminance standard deviation |
| `glareRatio` / `hasGlare` | `double` / `bool` | Share of blown-out pixels and whether it exceeds `maxGlareRatio` |
| `originalWidth` / `originalHeight` | `int` | Decoded resolution |
| `analyzedWidth` / `analyzedHeight` | `int` | Resolution fed to detectors |
| `processingTimeMs` | `int` | Analysis time in ms |
| `issues` | `List<String>` | Human-readable failed checks |
| `wasDownsampled` | `bool` | Whether the image was resized |

### `QualityResult` (from `ImageQualityValidator`)

| Property | Type | Description |
|---|---|---|
| `isValid` | `bool` | All checks passed |
| `issues` | `List<String>` | All detected issues |
| `errorMessage` | `String?` | First issue, or `null` when valid |
| `blurResult` | `BlurResult` | Variance, confidence, threshold, blur status |
| `brightnessResult` | `BrightnessResult` | Average brightness, thresholds, classification |
| `contrastResult` | `ContrastResult` | Contrast score, threshold, pass status |

---

## 🏗️ Architecture

```
 Flutter UI isolate                    Background isolate
┌─────────────────────┐   bytes    ┌──────────────────────────┐
│ ImageQualityGuard   │──────────▶ │ 1. Decode image          │
│   .analyze(bytes)   │            │ 2. Downsample*           │
│                     │            │ 3. Sharpness (tiles)     │
│                     │   result   │ 4. Brightness + contrast │
│ ImageQualityResult  │◀────────── │ 5. Glare                 │
└─────────────────────┘ (map)      └──────────────────────────┘
```
*Only when image exceeds `maxAnalysisDimension` (default 1280px).

---

## 🧮 How It Works

All checks share the same pipeline: **decode → convert to grayscale → measure**. The image is converted to a flat 8-bit luminance buffer (one byte per pixel) and every metric is computed from that buffer alone.

### Processing Pipeline

```
Raw Image Bytes
      │
      ▼
┌──────────────────┐
│  Decode (image   │   → img.Image (RGBA)
│  package)        │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────┐
│  Luminance Extraction    │   → Uint8List (0–255, one byte/pixel)
│  Rec. 601 luma:          │     0.299R + 0.587G + 0.114B
│  0.299R + 0.587G + 0.114B│
└────────┬─────────────────┘
         │
    ┌────┼────────────┬────────────┐
    │    │            │            │
    ▼    ▼            ▼            ▼
┌──────┐┌──────────┐┌──────────┐┌───────┐
│ Blur ││Brightness││ Contrast ││ Glare │
└──────┘└──────────┘└──────────┘└───────┘
```

---

### 🔍 Blur Detection — Tile-Based Laplacian Variance

Blur is measured with the **Laplacian variance method**, applied per region so that the parts of the image that actually carry detail decide the result:

1. **Normalize the scale** — Sharpness is always measured on at most 1280 px (the scale every `blurThreshold` is calibrated for), even with `fullResolution`. Area-averaged downsampling also suppresses sensor noise.

2. **Apply a Laplacian filter** — For every non-border pixel, compute the edge response:
   ```
   response = 4 × center − up − down − left − right
   ```
   This 4-neighbour Laplacian highlights rapid intensity changes (edges). Its variance is high for crisp edges and low when edges are smoothed out.

3. **Score tiles** — The image is split into a 4×4 grid. Tiles whose luminance standard deviation is below `minTileContrast` (blank areas) are ignored; the Laplacian variance of every remaining *informative* tile is computed with **Welford's online algorithm**.

4. **Pick the detailed regions** — `sharpnessScore` is the **80th percentile** of the tile scores. In a card or document photo most tiles show the table, plain card surface or a portrait, which are smooth even when the photo is perfectly focused; the percentile follows the tiles holding text and fine print, while still needing several sharp tiles so one noisy tile cannot pass a blurry photo. With fewer than `minInformativeTiles` informative tiles, the whole-image variance is used instead.

5. **Decide** — The image is blurry when `sharpnessScore < blurThreshold` (`isOutOfFocus`), or, when `minSharpTileRatio` is set, when too small a share of the tiles is sharp (`hasLowSharpCoverage`).

```
Sharp card on a table (16 tile scores, sorted):
  10 11 13 13 15 16 17 20 38 39 46 75 | 1003 1074 1618 2139
  └─── table, plain card, portrait ──┘   └─ text lines ──┘
  80th percentile → sharpnessScore ≈ 1003  ✅ (NID threshold 80)

Same card, out of focus:
  2 2 2 2 2 3 3 4 4 5 6 10 | 30 35 65 83
  80th percentile → sharpnessScore ≈ 30    ❌
```

> **Why Laplacian?** The Laplacian is isotropic (detects edges in all directions equally) and is widely used in camera auto-focus systems, making it a natural choice for general-purpose sharpness detection.

---

### ✨ Glare Detection

Glare is the **share of blown-out pixels** (luminance ≥ 250). A reflection on a laminated card wipes out the text underneath while the average brightness stays normal, so it cannot be caught by `maxBrightness`. When `glareRatio` exceeds `maxGlareRatio` (3% for the card, NID and document presets), the image is rejected with a glare issue.

---

### 💡 Brightness Analysis

Brightness is the **mean (average) luminance** across all pixels:

1. Each pixel is converted to grayscale using the **Rec. 601 luma formula**: `0.299R + 0.587G + 0.114B`
2. The average of all luminance values is calculated on a **0–255 scale**
3. The result is classified:
   - **Below `minBrightness`** → Too dark 🌑
   - **Above `maxBrightness`** → Too bright ☀️
   - **Within range** → Optimal ✅

---

### 🎨 Contrast Measurement

Contrast is the **population standard deviation** of pixel luminance values:

1. All luminance samples are analyzed in a single pass
2. Standard deviation is computed incrementally using **Welford's algorithm**
3. Classification:
   - **Low standard deviation** → Flat histogram, poor contrast (washed out)
   - **High standard deviation** → Wide tonal range, good contrast (vivid)

---

### 🧠 Memory Efficiency

Brightness, contrast, and every sharpness tile share a key optimization: **Welford's online algorithm** accumulates mean and variance incrementally. The package never materializes a per-pixel list of intermediate values, so memory stays constant regardless of image size.

---

## 📱 Example App

An interactive Flutter example with camera/gallery input, every preset, custom threshold sliders, image preview, and a focused results view:

```console
cd example
flutter run
```

### 🌐 Web Demo

The example app supports **Flutter web**. Visit the live demo to explore all features interactively in your browser:

🔗 **[Web Demo](https://Tanvirul-swe.github.io/image_quality_guard/)**

The web version includes image preview, quality profile selection, custom threshold sliders, and real-time results visualization.

#### Deployment

The web app is automatically deployed to **GitHub Pages** on every push to `main` via `.github/workflows/deploy.yml`.

The workflow uses GitHub's official Pages actions (`configure-pages`, `upload-pages-artifact`, `deploy-pages`) and auto-enables GitHub Pages on the repository.

To deploy manually:

```console
cd example
flutter build web --base-href /image_quality_guard/ --release
```

Then upload `example/build/web/` to GitHub Pages (Settings → Pages → Source → GitHub Actions).

---

## ⚡ Performance

- Analysis runs **locally** and synchronously after image decoding.
- Very large images can take noticeable time → resize camera images or use `maxAnalysisDimension` to auto-downsample.
- `ImageQualityGuard.analyze()` runs everything on a **background isolate**, keeping your UI smooth.
- Images are decoded **once** and reused across all checks.

---

## 🛠️ Error Handling

All errors extend `ImageQualityException`:

```dart
try {
  final result = await ImageQualityGuard.analyze(imageBytes);
} on ImageDecodeException {
  // ❌ Unsupported or corrupted file
} on ImageAnalysisException {
  // ❌ Unexpected analysis failure
} on ImageIsolateException {
  // ❌ Background isolate could not start
}
```

When using `ImageQualityValidator`, decode errors are thrown as `ArgumentError` for backward compatibility.

---

## 📄 License

BSD 3-Clause License — see [LICENSE](LICENSE).
