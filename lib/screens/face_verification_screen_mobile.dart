import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/face_api_service.dart';

class FaceVerificationScreen extends StatefulWidget {
  final String employeeNumber;
  final int clientId;
  final bool showResetButton;

  const FaceVerificationScreen({
    super.key,
    required this.employeeNumber,
    required this.clientId,
    this.showResetButton = true,
  });

  @override
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isProcessing = false;
  String _statusMessage = 'يرجى توجيه وجهك نحو الكاميرا';
  String _instructionMessage = 'وجه وجهك داخل الإطار';
  Color _borderColor = Colors.blue;
  bool _faceMatched = false;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableTracking: true,
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
        _startLivenessProcess();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'خطأ في تشغيل الكاميرا: $e';
        });
      }
    }
  }

  void _startLivenessProcess() {
    setState(() {
      _statusMessage = 'نظام التحقق من الهوية';
      _instructionMessage = 'يرجى الرمش بعينيك الآن للتأكد';
      _borderColor = Colors.blue;
    });

    Future.delayed(const Duration(seconds: 2), _autoCaptureAndVerify);
  }

  Future<void> _autoCaptureAndVerify() async {
    if (!mounted ||
        _isProcessing ||
        _controller == null ||
        !_controller!.value.isInitialized ||
        _faceMatched) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'جاري التحقق من ملامح الوجه...';
      _borderColor = Colors.orange;
    });

    try {
      final XFile rawImage = await _controller!.takePicture();

      final inputImage = InputImage.fromFilePath(rawImage.path);
      final faces = await _faceDetector.processImage(inputImage);

      if (kDebugMode) {
        print('🔍 Detected faces: ${faces.length}');
      }

      if (faces.isEmpty) {
        _handleFailure('لم يتم اكتشاف وجه. حاول التقريب.');
        return;
      }

      Face face = faces.first;
      if (faces.length > 1) {
        faces.sort((a, b) => (b.boundingBox.width * b.boundingBox.height)
            .compareTo(a.boundingBox.width * a.boundingBox.height));
        face = faces.first;
        if (kDebugMode) {
          print('⚠️ Found multiple faces, picking the largest one.');
        }
      }

      double headY = face.headEulerAngleY ?? 0;
      double headX = face.headEulerAngleX ?? 0;
      bool facingCamera = headY.abs() < 20 && headX.abs() < 20;

      if (!facingCamera) {
        _handleFailure('يرجى النظر مباشرة للكاميرا دون ميلان.');
        return;
      }

      if (face.leftEyeOpenProbability != null &&
          face.leftEyeOpenProbability! < 0.2) {
        _handleFailure('يرجى فتح عينيك بوضوح.');
        return;
      }

      final File imageFile = File(rawImage.path);
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      if (kDebugMode) {
        print('📡 Sending image to server (Size: ${bytes.length ~/ 1024} KB)');
      }

      final result = await FaceApiService.verifyFace(
        clientId: widget.clientId,
        employeeNumber: widget.employeeNumber,
        imageBase64: base64Image,
      );

      if (!mounted) return;

      if (result['Success'] == true) {
        setState(() {
          _faceMatched = true;
          _borderColor = Colors.green;
          _statusMessage = '✅ تم التحقق بنجاح';
          _instructionMessage = 'هوية حقيقية ومطابقة';
          _isProcessing = false;
        });
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        String errorMsg = result['Message'] ?? 'فشل التحقق';
        _handleFailure(errorMsg);
      }
    } catch (e) {
      _handleFailure('حدث خطأ أثناء الاتصال: $e');
    }
  }

  void _handleFailure(String message) {
    if (!mounted) return;
    setState(() {
      _borderColor = Colors.red;
      _statusMessage = message;
      _instructionMessage = 'يرجى المحاولة مرة أخرى';
      _isProcessing = false;
    });

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_faceMatched) {
        _startLivenessProcess();
      }
    });
  }

  Future<void> _resetFace() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'جاري إعادة تعيين بصمة الوجه...';
    });

    try {
      final result =
          await FaceApiService.resetFace(widget.clientId, widget.employeeNumber);
      if (result['Success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ تم إعادة تعيين بصمة الوجه بنجاح')),
          );
          Navigator.pop(context, false);
        }
      } else {
        _handleFailure(result['Message'] ?? 'فشل إعادة التعيين');
      }
    } catch (e) {
      _handleFailure('خطأ: $e');
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
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final previewSize = _controller?.value.previewSize;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final controller = _controller!;
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
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _instructionMessage,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
          Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _borderColor, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: _borderColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (_isProcessing)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 15),
                      child: CircularProgressIndicator(color: Colors.orange),
                    ),
                  Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _faceMatched ? Colors.green : Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (!_isProcessing && !_faceMatched) ...[
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _startLivenessProcess,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        if (widget.showResetButton) ...[
                          const SizedBox(width: 15),
                          OutlinedButton.icon(
                            onPressed: _resetFace,
                            icon: const Icon(Icons.delete_forever),
                            label: const Text('إعادة تعيين'),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                              foregroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ]
                ],
              ),
            ),
          ),
          Positioned(
            top: 50,
            left: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context, false),
            ),
          ),
        ],
      ),
    );
  }
}

