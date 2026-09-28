import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../../core/palette.dart';
import '../../models/face_verification_result.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/accuracy_gauge.dart';
import '../../widgets/verification_result_sheet.dart';
import 'voter_details_screen.dart';

/// Live webcam face-verification screen.
///
/// Shows a real-time camera preview (front camera preferred), lets the voter
/// capture a frame, then submits it to `/auth/login` for the full DeepFace
/// pipeline (image quality → liveness → anti-spoof → identity match).
///
/// On failure the detailed pipeline result is shown in a bottom sheet
/// (confidence gauge + per-stage breakdown) with the option to retry.
class FaceVerificationScreen extends StatefulWidget {
  const FaceVerificationScreen({super.key, required this.nid});

  final String nid;

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _controller;
  FaceDetector? _faceDetector;
  bool _isInitializing = true;
  bool _isCapturing = false;
  bool _isAnalyzingFrame = false;
  String? _cameraError;
  XFile? _capturedImage;
  String _challengePrompt = 'Blink once or slowly turn your head left, then back to center.';
  int _countdownValue = 0;
  Rect? _detectedFaceBounds;
  Size? _previewSize;
  bool _trackingSupported = true;
  double _challengeProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _trackingSupported = !kIsWeb;
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _cameraError = 'No camera found on this device.';
          _isInitializing = false;
        });
        return;
      }

      // Prefer the front (selfie) camera.
      CameraDescription selected;
      try {
        selected = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
        );
      } on StateError {
        selected = cameras.first;
      }

      final controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      try {
        await controller.setFocusMode(FocusMode.auto);
      } catch (_) {}
      try {
        await controller.setExposureMode(ExposureMode.auto);
      } catch (_) {}
      if (!mounted) return;

      _controller = controller;
      _previewSize = controller.value.previewSize;
      if (_trackingSupported) {
        _faceDetector = FaceDetector(
          options: FaceDetectorOptions(
            enableContours: true,
            enableClassification: true,
            enableLandmarks: true,
            enableTracking: true,
            performanceMode: FaceDetectorMode.fast,
          ),
        );
        await controller.startImageStream(_processCameraImage);
      }
      setState(() {
        _isInitializing = false;
        _cameraError = null;
      });
    } catch (e) {
      setState(() {
        _cameraError = 'Camera error: $e';
        _isInitializing = false;
      });
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _faceDetector?.close();
    _controller = null;
    super.dispose();
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_faceDetector == null || _isAnalyzingFrame || !mounted) return;
    _isAnalyzingFrame = true;
    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;
      final faces = await _faceDetector!.processImage(inputImage);
      if (!mounted) return;
      setState(() {
        _detectedFaceBounds = faces.isNotEmpty ? faces.first.boundingBox : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _detectedFaceBounds = null;
        });
      }
    } finally {
      _isAnalyzingFrame = false;
    }
  }

  Future<void> _stopImageStreamIfRunning() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {
        // Ignore failures when stopping the stream; we still want to try capture.
      }
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;

    final camera = controller.description;
    final sensorOrientation = camera.sensorOrientation;
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    final bytes = WriteBuffer();
    for (final plane in image.planes) {
      bytes.putUint8List(plane.bytes);
    }

    return InputImage.fromBytes(
      bytes: bytes.done().buffer.asUint8List(),
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _captureAndVerify() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      _showError('Camera is not ready yet.');
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final promptSequence = <Map<String, dynamic>>[
        {'text': 'Look straight at the camera', 'countdown': 2},
        {'text': 'Turn slightly left', 'countdown': 2},
        {'text': 'Return to center', 'countdown': 2},
        {'text': 'Blink once', 'countdown': 2},
      ];

      final capturedFrames = <XFile>[];
      await _stopImageStreamIfRunning();
      for (var index = 0; index < 8; index++) {
        final prompt = promptSequence[index % promptSequence.length];
        if (mounted) {
          setState(() {
            _challengePrompt = prompt['text'] as String;
            _countdownValue = prompt['countdown'] as int;
            _challengeProgress = index / 8;
          });
        }

        while (_countdownValue > 0 && mounted) {
          await Future<void>.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          setState(() => _countdownValue -= 1);
        }

        final XFile frame = await controller.takePicture();
        capturedFrames.add(frame);
        if (index == 7) {
          _capturedImage = frame;
        }
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      if (mounted) {
        setState(() => _challengeProgress = 1.0);
      }

      final auth = context.read<AuthProvider>();
      auth.clearError();

      final ok = await auth.loginVoter(
        nid: widget.nid,
        liveImage: capturedFrames.last,
        extraImages: capturedFrames.take(capturedFrames.length - 1).toList(),
      );
      if (!mounted) return;

      if (ok) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const VoterDetailsScreen()),
        );
      } else {
        final verification = auth.lastVerification;
        if (verification != null) {
          _showVerificationSheet(verification);
        } else {
          _showError(auth.error ?? 'Face verification failed.');
        }
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
      if (mounted && _trackingSupported && _controller != null && !_controller!.value.isStreamingImages) {
        try {
          await _controller!.startImageStream(_processCameraImage);
        } catch (_) {
          // If restarting the stream fails, the retry button will recreate it.
        }
      }
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _showVerificationSheet(FaceVerificationResult result) {
    showVerificationResultSheet(context, result);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Palette.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _retry() {
      setState(() {
        _capturedImage = null;
        _cameraError = null;
        _challengePrompt = 'Blink once or slowly turn your head left, then back to center.';
        _countdownValue = 0;
        _detectedFaceBounds = null;
        _challengeProgress = 0.0;
      });
    if (_controller == null) {
      _initCamera();
      return;
    }

    if (_trackingSupported && _controller != null && !_controller!.value.isStreamingImages) {
      try {
        _controller!.startImageStream(_processCameraImage);
      } catch (_) {
        // If restart fails, the next retry can reinitialize the camera.
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Palette.navyDeep,
      appBar: AppBar(
        backgroundColor: Palette.navyDeep,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Face Verification'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Text(
                    'Position your face inside the frame.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _trackingSupported ? _challengePrompt : 'Face tracking is limited on this platform.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Palette.goldSoft,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_countdownValue > 0)
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        'Capture in $_countdownValue',
                        key: ValueKey<int>(_countdownValue),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (_countdownValue > 0) const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: _challengeProgress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withOpacity(0.14),
                        valueColor: const AlwaysStoppedAnimation<Color>(Palette.goldSoft),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _trackingSupported
                        ? 'The camera will capture a short burst to confirm liveness.'
                        : 'Live face tracking is not available on this platform.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Camera preview / state area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    color: Palette.navy,
                    child: _buildPreview(),
                  ),
                ),
              ),
            ),

            // NID chip
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'National ID: ${widget.nid}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: _isCapturing
                  ? const SizedBox(
                      height: 52,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          valueColor: AlwaysStoppedAnimation<Color>(Palette.goldSoft),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: auth.loading || _isInitializing
                                  ? null
                                  : _captureAndVerify,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Palette.navy,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    Palette.navy.withOpacity(0.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              icon: const Icon(Icons.camera_alt_rounded),
                              label: const Text(
                                'Verify',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_cameraError != null || _capturedImage != null) ...[
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: _retry,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Retry'),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation<Color>(Palette.goldSoft),
            ),
            SizedBox(height: 12),
            Text(
              'Starting camera…',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_cameraError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white38, size: 40),
              const SizedBox(height: 12),
              Text(
                _cameraError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: Text(
          'Camera unavailable.',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        Container(color: Colors.black.withOpacity(0.06)),
        // Face guide with a little headroom, similar to the OS camera app.
        Center(
          child: Container(
            width: 250,
            height: 320,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(150),
              border: Border.all(
                color: Colors.lightBlueAccent.withOpacity(0.9),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.lightBlueAccent.withOpacity(0.18),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
      child: Stack(
          children: [
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Text(
                    'Keep a little space above your hair',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.88),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Text(
                    'Align your face inside the guide',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_trackingSupported && _detectedFaceBounds != null && _previewSize != null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _FaceBoundsPainter(
                  detected: _detectedFaceBounds!,
                  previewSize: _previewSize!,
                ),
              ),
            ),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 18,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.45),
              borderRadius: BorderRadius.circular(14),
            ),
                child: const Text(
                  'Move closer until your face fills the guide, with a small gap at the top.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                height: 1.3,
              ),
            ),
          ),
        ),
        if (_countdownValue > 0)
          Positioned(
            top: 18,
            left: 18,
            right: 18,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Text(
                  _challengePrompt,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FaceBoundsPainter extends CustomPainter {
  _FaceBoundsPainter({
    required this.detected,
    required this.previewSize,
  });

  final Rect detected;
  final Size previewSize;

  @override
  void paint(Canvas canvas, Size size) {
    if (previewSize.width == 0 || previewSize.height == 0) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.lightGreenAccent.withOpacity(0.95);

    final scaleX = size.width / previewSize.height;
    final scaleY = size.height / previewSize.width;

    final rect = Rect.fromLTWH(
      size.width - ((detected.bottom + detected.height) * scaleX),
      detected.left * scaleY,
      detected.height * scaleX,
      detected.width * scaleY,
    );

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _FaceBoundsPainter oldDelegate) {
    return oldDelegate.detected != detected || oldDelegate.previewSize != previewSize;
  }
}

/// Convenience helper to launch the screen (used by the login flow).
Future<void> pushFaceVerificationScreen(
  BuildContext context, {
  required String nid,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => FaceVerificationScreen(nid: nid),
    ),
  );
}

