import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_api_service.dart';

class FaceEnrollmentScreen extends StatefulWidget {
  final String employeeNumber;
  final int clientId;

  const FaceEnrollmentScreen({
    super.key,
    required this.employeeNumber,
    required this.clientId,
  });

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isProcessing = false;
  String _statusMessage = 'يرجى توجيه وجهك نحو الكاميرا';
  Color _borderColor = Colors.white.withOpacity(0.5);

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableClassification: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'خطأ في تشغيل الكاميرا: $e';
          _borderColor = Colors.red;
        });
      }
    }
  }

  Future<void> _captureAndEnroll() async {
    if (_isProcessing ||
        _controller == null ||
        !_controller!.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'جاري تحليل ملامح الوجه...';
      _borderColor = Colors.orange;
    });

    try {
      final image = await _controller!.takePicture();
      final inputImage = InputImage.fromFilePath(image.path);

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isEmpty) {
        setState(() {
          _statusMessage = 'لم يتم اكتشاف وجه. حاول الاقتراب من الكاميرا.';
          _isProcessing = false;
          _borderColor = Colors.red;
        });
        return;
      }

      Face face = faces.first;
      if (faces.length > 1) {
        faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
            .compareTo(a.boundingBox.width * a.boundingBox.height));
        face = faces.first;
      }

      double headY = face.headEulerAngleY ?? 0;
      double headX = face.headEulerAngleX ?? 0;
      if (headY.abs() > 20 || headX.abs() > 20) {
        setState(() {
          _statusMessage = 'يرجى النظر مباشرة للكاميرا دون ميلان.';
          _isProcessing = false;
          _borderColor = Colors.red;
        });
        return;
      }

      if (face.leftEyeOpenProbability != null &&
          face.leftEyeOpenProbability! < 0.2) {
        setState(() {
          _statusMessage = 'يرجى التأكد من فتح عينيك جيداً للصورة.';
          _isProcessing = false;
          _borderColor = Colors.red;
        });
        return;
      }

      setState(() {
        _borderColor = Colors.green;
        _statusMessage = '✅ تم التعرف على الوجه. جاري الحفظ...';
      });

      final bytes = await File(image.path).readAsBytes();
      final base64Image = base64Encode(bytes);

      final result = await FaceApiService.enrollFace(
        clientId: widget.clientId,
        employeeNumber: widget.employeeNumber,
        imageBase64: base64Image,
      );

      if (result['Success'] == true) {
        if (mounted) {
          setState(() {
            _statusMessage = '✅ تم تسجيل الوجه بنجاح';
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم تسجيل الوجه بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) {
            Navigator.pop(context, true);
          }
        }
      } else {
        setState(() {
          _statusMessage = result['Message'] ?? 'فشل التسجيل';
          _isProcessing = false;
          _borderColor = Colors.red;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'حدث خطأ: $e';
          _isProcessing = false;
          _borderColor = Colors.red;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _faceDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل الوجه'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: ClipRect(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final controller = _controller!;
                        final previewSize = controller.value.previewSize;
                        final screenAspect =
                            constraints.maxWidth / constraints.maxHeight;
                        final cameraAspect = previewSize == null
                            ? controller.value.aspectRatio
                            : previewSize.height / previewSize.width;

                        double scale = cameraAspect / screenAspect;
                        if (scale < 1) scale = 1 / scale;

                        return Transform.scale(
                          scale: scale,
                          child: Center(child: CameraPreview(controller)),
                        );
                      },
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 280,
                  height: 380,
                  decoration: BoxDecoration(
                    border: Border.all(color: _borderColor, width: 4),
                    borderRadius: BorderRadius.circular(150),
                    boxShadow: [
                      BoxShadow(
                        color: _borderColor.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _statusMessage.contains('خطأ')
                        ? Colors.red
                        : Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _captureAndEnroll,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('التقاط وتسجيل',
                        style: TextStyle(fontSize: 18)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

