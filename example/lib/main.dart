import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_quality_guard/image_quality_guard.dart';

void main() {
  runApp(const ImageQualityGuardExampleApp());
}

class ImageQualityGuardExampleApp extends StatelessWidget {
  const ImageQualityGuardExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF176B5B);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Image Quality Guard',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF17201E),
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFDDE5E2)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const QualityGuardPage(),
    );
  }
}

class QualityGuardPage extends StatefulWidget {
  const QualityGuardPage({super.key});

  @override
  State<QualityGuardPage> createState() => _QualityGuardPageState();
}

class _QualityGuardPageState extends State<QualityGuardPage> {
  static const _profiles = <QualityProfile>[
    QualityProfile(
      name: 'Default',
      description: 'Balanced checks for everyday images',
      icon: Icons.auto_awesome_outlined,
      config: QualityConfig(),
    ),
    QualityProfile(
      name: 'Card scan',
      description: 'IDs, bank cards, and licenses',
      icon: Icons.credit_card_outlined,
      config: QualityConfig.cardScanning,
    ),
    QualityProfile(
      name: 'Document',
      description: 'Forms, receipts, and printed text',
      icon: Icons.description_outlined,
      config: QualityConfig.documentScanning,
    ),
    QualityProfile(
      name: 'Photo',
      description: 'High-quality photo capture',
      icon: Icons.photo_camera_outlined,
      config: QualityConfig.photoCapture,
    ),
    QualityProfile(
      name: 'Relaxed',
      description: 'More forgiving quality limits',
      icon: Icons.sentiment_satisfied_alt_outlined,
      config: QualityConfig.relaxed,
    ),
    QualityProfile(
      name: 'Strict',
      description: 'Higher quality requirements',
      icon: Icons.verified_outlined,
      config: QualityConfig.strict,
    ),
    QualityProfile(
      name: 'Custom',
      description: 'Set your own minimum quality thresholds',
      icon: Icons.tune,
      config: QualityConfig(),
      isCustom: true,
    ),
  ];

  final ImagePicker _picker = ImagePicker();

  Uint8List? _imageBytes;
  String? _fileName;
  QualityResult? _result;
  int _profileIndex = 0;
  double _customSharpness = 100;
  double _customBrightness = 40;
  double _customContrast = 50;
  bool _isPicking = false;
  bool _isAnalyzing = false;
  String? _errorMessage;

  QualityProfile get _profile => _profiles[_profileIndex];

  QualityConfig get _activeConfig {
    if (!_profile.isCustom) return _profile.config;
    return QualityConfig(
      blurThreshold: _customSharpness,
      minBrightness: _customBrightness,
      minContrast: _customContrast,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPicking || _isAnalyzing) return;

    setState(() {
      _isPicking = true;
      _errorMessage = null;
    });

    try {
      final file = await _picker.pickImage(source: source);
      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      setState(() {
        _imageBytes = bytes;
        _fileName = file.name;
        _result = null;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _pickerErrorMessage(error);
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not open that image. Please try another one.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  String _pickerErrorMessage(PlatformException error) {
    if (error.code.contains('camera_access_denied')) {
      return 'Camera access is disabled. Allow it in device settings.';
    }
    if (error.code.contains('photo_access_denied')) {
      return 'Photo access is disabled. Allow it in device settings.';
    }
    return error.message ?? 'Could not open the image picker.';
  }

  Future<void> _analyze() async {
    final bytes = _imageBytes;
    if (bytes == null || _isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final validator = ImageQualityValidator(config: _activeConfig);
      final result = await validator.validate(bytes);
      if (!mounted) return;
      setState(() {
        _result = result;
      });
    } on ArgumentError {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'This file is not a supported image.';
      });
    } on Object catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'The image could not be analyzed. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _changeProfile(int? index) {
    if (index == null || index == _profileIndex) return;
    setState(() {
      _profileIndex = index;
      _result = null;
      _errorMessage = null;
    });
  }

  void _changeCustomSharpness(double value) {
    setState(() {
      _customSharpness = value;
      _result = null;
    });
  }

  void _changeCustomBrightness(double value) {
    setState(() {
      _customBrightness = value;
      _result = null;
    });
  }

  void _changeCustomContrast(double value) {
    setState(() {
      _customContrast = value;
      _result = null;
    });
  }

  void _clearImage() {
    setState(() {
      _imageBytes = null;
      _fileName = null;
      _result = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _BrandMark(),
            SizedBox(width: 12),
            Text(
              'Image Quality Guard',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Check image quality',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF17201E),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Choose an image and check it for blur, lighting, and contrast.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(color: const Color(0xFF64706D)),
                  ),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 820;
                      final imagePanel = _ImagePanel(
                        bytes: _imageBytes,
                        fileName: _fileName,
                        isPicking: _isPicking,
                        onGallery: () => _pickImage(ImageSource.gallery),
                        onCamera: () => _pickImage(ImageSource.camera),
                        onClear: _clearImage,
                      );
                      final actionPanel = _ActionPanel(
                        profiles: _profiles,
                        profileIndex: _profileIndex,
                        hasImage: _imageBytes != null,
                        isAnalyzing: _isAnalyzing,
                        result: _result,
                        errorMessage: _errorMessage,
                        customSharpness: _customSharpness,
                        customBrightness: _customBrightness,
                        customContrast: _customContrast,
                        onProfileChanged: _changeProfile,
                        onSharpnessChanged: _changeCustomSharpness,
                        onBrightnessChanged: _changeCustomBrightness,
                        onContrastChanged: _changeCustomContrast,
                        onAnalyze: _analyze,
                      );

                      if (!isWide) {
                        return Column(
                          children: [
                            imagePanel,
                            const SizedBox(height: 16),
                            actionPanel,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 11, child: imagePanel),
                          const SizedBox(width: 20),
                          Expanded(flex: 9, child: actionPanel),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_search, color: Colors.white, size: 20),
    );
  }
}

class _ImagePanel extends StatelessWidget {
  const _ImagePanel({
    required this.bytes,
    required this.fileName,
    required this.isPicking,
    required this.onGallery,
    required this.onCamera,
    required this.onClear,
  });

  final Uint8List? bytes;
  final String? fileName;
  final bool isPicking;
  final VoidCallback onGallery;
  final VoidCallback onCamera;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final hasImage = bytes != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Image',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
                if (hasImage)
                  IconButton(
                    onPressed: onClear,
                    tooltip: 'Remove image',
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Container(
                  color: const Color(0xFFEAF0EE),
                  child: hasImage
                      ? Image.memory(
                          bytes!,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        )
                      : const _EmptyImageState(),
                ),
              ),
            ),
            if (fileName != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.image_outlined,
                    size: 17,
                    color: Color(0xFF64706D),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      fileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF64706D)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatBytes(bytes!.length),
                    style: const TextStyle(color: Color(0xFF64706D)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isPicking ? null : onGallery,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isPicking ? null : onCamera,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int value) {
    if (value >= 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(value / 1024).toStringAsFixed(0)} KB';
  }
}

class _EmptyImageState extends StatelessWidget {
  const _EmptyImageState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 46,
            color: Color(0xFF71807C),
          ),
          SizedBox(height: 10),
          Text(
            'No image selected',
            style: TextStyle(
              color: Color(0xFF42504C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.profiles,
    required this.profileIndex,
    required this.hasImage,
    required this.isAnalyzing,
    required this.result,
    required this.errorMessage,
    required this.customSharpness,
    required this.customBrightness,
    required this.customContrast,
    required this.onProfileChanged,
    required this.onSharpnessChanged,
    required this.onBrightnessChanged,
    required this.onContrastChanged,
    required this.onAnalyze,
  });

  final List<QualityProfile> profiles;
  final int profileIndex;
  final bool hasImage;
  final bool isAnalyzing;
  final QualityResult? result;
  final String? errorMessage;
  final double customSharpness;
  final double customBrightness;
  final double customContrast;
  final ValueChanged<int?> onProfileChanged;
  final ValueChanged<double> onSharpnessChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onContrastChanged;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    final profile = profiles[profileIndex];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Quality profile',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const Key('quality-profile-dropdown'),
              initialValue: profileIndex,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              items: [
                for (var index = 0; index < profiles.length; index++)
                  DropdownMenuItem(
                    value: index,
                    child: Row(
                      children: [
                        Icon(profiles[index].icon, size: 20),
                        const SizedBox(width: 10),
                        Text(profiles[index].name),
                      ],
                    ),
                  ),
              ],
              onChanged: isAnalyzing ? null : onProfileChanged,
            ),
            const SizedBox(height: 8),
            Text(
              profile.description,
              style: const TextStyle(color: Color(0xFF64706D)),
            ),
            if (profile.isCustom) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _ThresholdSlider(
                label: 'Minimum sharpness',
                value: customSharpness,
                min: 10,
                max: 500,
                divisions: 49,
                onChanged: isAnalyzing ? null : onSharpnessChanged,
              ),
              _ThresholdSlider(
                label: 'Minimum brightness',
                value: customBrightness,
                min: 0,
                max: 200,
                divisions: 40,
                onChanged: isAnalyzing ? null : onBrightnessChanged,
              ),
              _ThresholdSlider(
                label: 'Minimum contrast',
                value: customContrast,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: isAnalyzing ? null : onContrastChanged,
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: hasImage && !isAnalyzing ? onAnalyze : null,
              icon: isAnalyzing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_fix_high_outlined),
              label: Text(isAnalyzing ? 'Analyzing...' : 'Analyze image'),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              _ErrorNotice(message: errorMessage!),
            ],
            if (result != null) ...[
              const SizedBox(height: 20),
              _ResultView(result: result!),
            ] else if (errorMessage == null) ...[
              const SizedBox(height: 24),
              _WaitingState(hasImage: hasImage),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThresholdSlider extends StatelessWidget {
  const _ThresholdSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 44),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF0EE),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Color(0xFF30423D),
                    fontWeight: FontWeight.w700,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: value.toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _WaitingState extends StatelessWidget {
  const _WaitingState({required this.hasImage});

  final bool hasImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6F5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        children: [
          Icon(
            hasImage ? Icons.fact_check_outlined : Icons.image_search,
            size: 34,
            color: const Color(0xFF71807C),
          ),
          const SizedBox(height: 10),
          Text(
            hasImage ? 'Ready to analyze' : 'Select an image to begin',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF42504C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.result});

  final QualityResult result;

  @override
  Widget build(BuildContext context) {
    final passed = result.isValid;
    final statusColor =
        passed ? const Color(0xFF167052) : const Color(0xFFB5472D);
    final statusBackground =
        passed ? const Color(0xFFE7F5EE) : const Color(0xFFFFEDE7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusBackground,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                passed ? Icons.check_circle : Icons.error,
                color: statusColor,
                size: 26,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      passed ? 'Quality check passed' : 'Needs another photo',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (!passed) ...[
                      const SizedBox(height: 4),
                      Text(
                        _friendlyIssues(result),
                        style: const TextStyle(color: Color(0xFF68463D)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Results',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        _CheckRow(
          icon: Icons.center_focus_strong_outlined,
          label: 'Sharpness',
          value: result.blurResult.variance.toStringAsFixed(1),
          passed: !result.blurResult.isBlurry,
        ),
        const Divider(height: 1),
        _CheckRow(
          icon: Icons.light_mode_outlined,
          label: 'Brightness',
          value: result.brightnessResult.averageBrightness.toStringAsFixed(1),
          passed: result.brightnessResult.isOptimal,
        ),
        const Divider(height: 1),
        _CheckRow(
          icon: Icons.contrast_outlined,
          label: 'Contrast',
          value: result.contrastResult.contrastScore.toStringAsFixed(1),
          passed: result.contrastResult.hasGoodContrast,
        ),
      ],
    );
  }

  String _friendlyIssues(QualityResult value) {
    final issues = <String>[];
    if (value.blurResult.isBlurry) issues.add('Hold the camera steady');
    if (!value.brightnessResult.isOptimal) {
      switch (value.brightnessResult.level) {
        case BrightnessLevel.tooDark:
          issues.add('Use more light');
        case BrightnessLevel.tooBright:
          issues.add('Reduce glare or light');
        case BrightnessLevel.optimal:
          break;
      }
    }
    if (!value.contrastResult.hasGoodContrast) {
      issues.add('Use a clearer background');
    }
    return issues.join(' | ');
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.passed,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool passed;

  @override
  Widget build(BuildContext context) {
    final color = passed ? const Color(0xFF167052) : const Color(0xFFB5472D);

    return SizedBox(
      height: 58,
      child: Row(
        children: [
          Icon(icon, size: 21, color: const Color(0xFF53625E)),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF64706D),
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            color: color,
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDE7),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB5472D)),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}

class QualityProfile {
  const QualityProfile({
    required this.name,
    required this.description,
    required this.icon,
    required this.config,
    this.isCustom = false,
  });

  final String name;
  final String description;
  final IconData icon;
  final QualityConfig config;
  final bool isCustom;
}
