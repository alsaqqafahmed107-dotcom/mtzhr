import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:provider/provider.dart';
import '../services/face_api_service.dart';
import '../services/language_service.dart';
import '../services/translations.dart';
import '../services/liveness_detection_service.dart';

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

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with WidgetsBindingObserver {
  static const bool _enableRemoteDebugTelemetry = true;
  static const String _debugEnvPath = 'd:\\new\\.dbg\\face-detection-fail.env';
  String? _debugServerUrl;
  String? _debugSessionId;
  // #region debug-point A:reporting-helper
  Future<void> _reportDebugEvent(
    String hypothesisId,
    String location,
    String msg, {
    Map<String, dynamic>? data,
  }) async {
    if (!_enableRemoteDebugTelemetry) return;
    try {
      if (_debugServerUrl == null || _debugSessionId == null) {
        try {
          final envText = await File(_debugEnvPath).readAsString();
          for (final line in envText.split('\n')) {
            if (line.startsWith('DEBUG_SERVER_URL=')) {
              _debugServerUrl =
                  line.substring('DEBUG_SERVER_URL='.length).trim();
            } else if (line.startsWith('DEBUG_SESSION_ID=')) {
              _debugSessionId =
                  line.substring('DEBUG_SESSION_ID='.length).trim();
            }
          }
        } catch (_) {}
      }
      final url = _debugServerUrl ?? 'http://192.168.1.163:7777/event';
      final session = _debugSessionId ?? 'face-detection-fail';
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 2);
      final req = await client.postUrl(
        Uri.parse(url),
      );
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode({
        'sessionId': session,
        'runId': 'pre-fix',
        'hypothesisId': hypothesisId,
        'location': location,
        'msg': '[DEBUG] $msg',
        'data': data ?? const {},
        'ts': DateTime.now().millisecondsSinceEpoch,
        'traceId':
            '${widget.employeeNumber}-${DateTime.now().microsecondsSinceEpoch}',
      }));
      await (await req.close()).drain<void>();
      client.close(force: true);
    } catch (_) {}
  }
  // #endregion

  CameraController? _controller;
  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _isVerifyingOnServer = false;
  String _statusMessage = '';
  String _instructionMessage = '';
  String _challengeMessage = '';
  Color _borderColor = Colors.blue;
  bool _faceMatched = false;
  bool _completedSuccessfully = false;
  bool _closeHandled = false;
  Map<String, dynamic>? _successfulVerificationPayload;
  bool _verificationStartRequested = false;
  bool _streamPausedForStillCapture = false;
  Face? _currentDetectedFace;
  int _currentFaceCount = 0;
  PassiveLivenessSnapshot _analysisSnapshot =
      const PassiveLivenessSnapshot.empty();
  PassiveLivenessSnapshot? _lockedAnalysisSnapshot;

  // ⚡ إصلاح 1: تتبع وقت بدء الجلسة لحساب المدة بشكل صحيح
  final DateTime _sessionStartTime = DateTime.now();

  // ⚡ إصلاح 2: نظام Pre-Capture JPG (نفس الحل في التسجيل):
  Uint8List? _lastProactiveCapturedJpg;
  Face? _lastProactiveCapturedFace;
  Timer? _proactiveCaptureTimer;
  bool _isProactiveCapturing = false;

  final LivenessDetectionService _livenessService = LivenessDetectionService();
  LivenessStatus _livenessStatus = LivenessStatus.initializing;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      enableLandmarks: true,
      enableContours: true,
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
    ),
  );

  Face? _previousTrackedFace;
  int _frameCounter = 0;
  static const int _processEveryNthFrame =
      3; // ⚡ من 2 إلى 3 → تقليل استهلاك المعالج 33%
  int _lastTelemetryFaceCount = -999;
  bool _isStartingImageStream = false;

  // ⚡ نفس حماية Race Condition للتسجيل (تطبيقها على التحقق للاتساق):
  // تخزين آخر إطار وجه صالح كـ Fallback عند فشل takePicture بسبب تعليق الكاميرا.
  Uint8List? _lastValidFrameBytes;
  Size? _lastValidFrameSize;
  InputImageRotation? _lastValidFrameRotation;
  Face? _lastValidFace;
  bool _verificationCaptureCompleted = false;
  int _noFaceGraceStreak = 0;

  static const Map<DeviceOrientation, int> _cameraOrientationMap = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lang = Provider.of<LanguageService>(context, listen: false)
        .currentLocale
        .languageCode;
    _statusMessage = Translations.getText('face_point_to_camera', lang);
    _instructionMessage = lang == 'ar'
        ? 'لا توجد تحديات يدوية. فقط أبقِ وجهك داخل الإطار واترك النظام يحلل الحياة والهوية تلقائياً.'
        : 'No manual challenges. Keep your face inside the frame and let the system analyze liveness automatically.';
    _challengeMessage = lang == 'ar'
        ? 'جاري فحص التموضع وحيوية الوجه...'
        : 'Analyzing face position and passive liveness...';
    _livenessService.initialize();
    _setupLivenessListeners();
    _initializeCamera();
    // ⚡ إصلاح 2: بدء مؤقت التقاط الاستباقي لصور JPG
    _startProactiveCaptureLoop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _proactiveCaptureTimer?.cancel();
    _controller?.stopImageStream();
    _controller?.dispose();
    _faceDetector.close();
    _livenessService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // #region debug-point B:lifecycle-state
    unawaited(_reportDebugEvent(
      'B',
      'face_verification_screen_mobile.dart:didChangeAppLifecycleState',
      'App lifecycle state changed',
      data: {
        'state': state.name,
        'controllerExists': _controller != null,
        'controllerInitialized': _controller?.value.isInitialized ?? false,
        'isStreamingImages': _controller?.value.isStreamingImages ?? false,
        'isVerifyingOnServer': _isVerifyingOnServer,
        'verificationCaptureCompleted': _verificationCaptureCompleted,
      },
    ));
    // #endregion
    unawaited(_handleAppLifecycleState(state));
  }

  Future<void> _handleAppLifecycleState(AppLifecycleState state) async {
    if (!mounted) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      await _disposeCameraController(updateUi: mounted);
      return;
    }

    if (state == AppLifecycleState.resumed &&
        mounted &&
        _controller == null &&
        !_completedSuccessfully) {
      await _initializeCamera();
    }
  }

  CameraController _buildCameraController(
    CameraDescription camera, {
    required ResolutionPreset preset,
    ImageFormatGroup? formatGroup,
  }) {
    return CameraController(
      camera,
      preset,
      enableAudio: false,
      imageFormatGroup: formatGroup,
    );
  }

  Future<void> _configureCameraController(CameraController controller) async {
    try {
      await controller.setFlashMode(FlashMode.off);
    } catch (_) {}
    try {
      await controller.setFocusMode(FocusMode.auto);
    } catch (_) {}
    try {
      await controller.setExposureMode(ExposureMode.auto);
    } catch (_) {}
    try {
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
    } catch (_) {}
  }

  Future<void> _disposeCameraController({bool updateUi = false}) async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      try {
        if (controller.value.isStreamingImages) {
          await controller.stopImageStream();
        }
      } catch (_) {}
      try {
        await controller.dispose();
      } catch (_) {}
    }
    if (updateUi && mounted) {
      setState(() {
        _isInitializing = true;
      });
    }
  }

  PassiveLivenessSnapshot get _displaySnapshot =>
      _lockedAnalysisSnapshot ?? _analysisSnapshot;

  int get _displayCompletedRequiredSignals {
    final snapshot = _displaySnapshot;
    if (snapshot.requiredSignals <= 0) return 0;
    return snapshot.completedSignals.clamp(0, snapshot.requiredSignals);
  }

  double get _displaySignalProgress {
    final snapshot = _displaySnapshot;
    if (snapshot.requiredSignals <= 0) return 0.0;
    return (_displayCompletedRequiredSignals / snapshot.requiredSignals)
        .clamp(0.0, 1.0);
  }

  String _buildSignalSummaryText() {
    final snapshot = _displaySnapshot;
    if (_lang() == 'ar') {
      return 'المؤشرات المجتازة: ${snapshot.completedSignals}/${snapshot.totalSignals} | المطلوب للاعتماد: ${snapshot.requiredSignals}';
    }
    return 'Passed indicators: ${snapshot.completedSignals}/${snapshot.totalSignals} | Required: ${snapshot.requiredSignals}';
  }

  String _buildOverallSnapshotText() {
    final snapshot = _displaySnapshot;
    if (_lang() == 'ar') {
      return 'التقييم العام للّقطة: ${((snapshot.overallScore) * 100).round()}%';
    }
    return 'Overall frame score: ${((snapshot.overallScore) * 100).round()}%';
  }

  String _getFacePresenceGuidance(int faceCount) {
    if (_lang() == 'ar') {
      if (faceCount <= 0) {
        return 'لم يتم اكتشاف وجه، يرجى الوقوف أمام الكاميرا بشكل صحيح داخل الإطار.';
      }
      if (faceCount > 1) {
        return 'تم اكتشاف أكثر من وجه في الإطار. يجب أن يظهر وجه موظف واحد فقط.';
      }
      return _analysisSnapshot.guidanceAr;
    }

    if (faceCount <= 0) {
      return 'No face detected. Please stand clearly in front of the camera.';
    }
    if (faceCount > 1) {
      return 'More than one face detected. Only one employee face is allowed in the frame.';
    }
    return _analysisSnapshot.guidanceEn;
  }

  // ⚡ إصلاح 2: نظام التقاط الاستباقي (نفس منطق التسجيل)
  void _startProactiveCaptureLoop() {
    _proactiveCaptureTimer = Timer.periodic(
        Duration(milliseconds: Platform.isIOS ? 1800 : 3000), (timer) async {
      if (!mounted ||
          _isInitializing ||
          _isProcessing ||
          _isVerifyingOnServer ||
          _isProactiveCapturing ||
          _verificationCaptureCompleted ||
          _livenessStatus == LivenessStatus.spoofDetected) {
        return;
      }
      if (_livenessStatus != LivenessStatus.waitingForFace &&
          _livenessStatus != LivenessStatus.challengeInProgress) {
        return;
      }
      try {
        _isProactiveCapturing = true;
        await _runProactiveCaptureOnce();
      } catch (_) {
      } finally {
        if (mounted) _isProactiveCapturing = false;
      }
    });
  }

  Future<void> _runProactiveCaptureOnce() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    final XFile? img = await _tryTakePictureOrNull(timeoutMs: 2200);
    if (img == null) return;
    final bytes = await File(img.path)
        .readAsBytes()
        .timeout(const Duration(milliseconds: 1500));
    final inputImage = InputImage.fromFilePath(img.path);
    final faces = await _faceDetector
        .processImage(inputImage)
        .timeout(const Duration(milliseconds: 2000));
    if (faces.length == 1) {
      if (kDebugMode) {
        print(
            '📸 [Verify-Proactive] ✅ تم التقاط صورة JPG احتياطية بحجم ${bytes.length ~/ 1024}KB | وجه موجود');
      }
      _lastProactiveCapturedJpg = bytes;
      _lastProactiveCapturedFace = faces.first;
    } else {
      _lastProactiveCapturedJpg = null;
      _lastProactiveCapturedFace = null;
    }
  }

  Future<bool> _ensureFreshIosProactiveCapture({int attempts = 2}) async {
    if (!Platform.isIOS) {
      return _lastProactiveCapturedJpg != null &&
          _lastProactiveCapturedFace != null;
    }

    for (int attempt = 1; attempt <= attempts; attempt++) {
      // #region debug-point A:ios-proactive-capture-attempt
      unawaited(_reportDebugEvent(
        'A',
        'face_verification_screen_mobile.dart:_ensureFreshIosProactiveCapture',
        'Starting iPhone proactive JPG attempt',
        data: {
          'attempt': attempt,
          'attempts': attempts,
          'existingJpg': _lastProactiveCapturedJpg != null,
          'existingFace': _lastProactiveCapturedFace != null,
        },
      ));
      // #endregion
      try {
        await _runProactiveCaptureOnce();
      } catch (_) {}

      if (_lastProactiveCapturedJpg != null &&
          _lastProactiveCapturedFace != null) {
        // #region debug-point A:ios-proactive-capture-success
        unawaited(_reportDebugEvent(
          'A',
          'face_verification_screen_mobile.dart:_ensureFreshIosProactiveCapture',
          'iPhone proactive JPG ready before verification',
          data: {
            'attempt': attempt,
            'attempts': attempts,
            'imageKb': _lastProactiveCapturedJpg!.length ~/ 1024,
            'boundingBoxWidth': _lastProactiveCapturedFace!.boundingBox.width,
            'boundingBoxHeight': _lastProactiveCapturedFace!.boundingBox.height,
          },
        ));
        // #endregion
        if (kDebugMode) {
          print(
              '📸 [Verify-iPhone] تم تجهيز JPG نهائية صالحة قبل الإرسال (attempt=$attempt/$attempts)');
        }
        return true;
      }

      if (attempt < attempts) {
        await Future.delayed(const Duration(milliseconds: 180));
      }
    }

    // #region debug-point A:ios-proactive-capture-failed
    unawaited(_reportDebugEvent(
      'A',
      'face_verification_screen_mobile.dart:_ensureFreshIosProactiveCapture',
      'iPhone proactive JPG unavailable before verification',
      data: {
        'attempts': attempts,
        'existingJpg': _lastProactiveCapturedJpg != null,
        'existingFace': _lastProactiveCapturedFace != null,
      },
    ));
    // #endregion
    return false;
  }

  Future<XFile?> _tryTakePictureOrNull({required int timeoutMs}) async {
    try {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) return null;
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
        _streamPausedForStillCapture = true;
      }
      return await controller.takePicture().timeout(
            Duration(milliseconds: timeoutMs),
          );
    } catch (_) {
      return null;
    } finally {
      await _resumeImageStreamIfNeeded();
    }
  }

  Future<void> _resumeImageStreamIfNeeded() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (_verificationCaptureCompleted || _isVerifyingOnServer) return;
    if (_streamPausedForStillCapture && !controller.value.isStreamingImages) {
      try {
        await _startFrameStreaming();
      } catch (_) {
      } finally {
        _streamPausedForStillCapture = false;
      }
    }
  }

  String _lang() => Provider.of<LanguageService>(context, listen: false)
      .currentLocale
      .languageCode;

  String _t(String key) => Translations.getText(key, _lang());

  String _tParams(String key, Map<String, String> params) =>
      Translations.getTextWithParams(key, _lang(), params);

  List<int> _extractFaceTextureSamples(CameraImage image, Face? face) {
    if (image.planes.isEmpty) return const <int>[];

    final plane = image.planes.first;
    final bytes = plane.bytes;
    if (bytes.isEmpty) return const <int>[];

    final pixelStride = plane.bytesPerPixel ?? (Platform.isIOS ? 4 : 1);
    final bytesPerRow = plane.bytesPerRow;
    final frameWidth = image.width;
    final frameHeight = image.height;

    int left = 0;
    int top = 0;
    int right = frameWidth - 1;
    int bottom = frameHeight - 1;

    if (face != null) {
      final box = face.boundingBox;
      final paddingX = (box.width * 0.12).round();
      final paddingY = (box.height * 0.12).round();
      left = ((box.left.round() - paddingX).clamp(0, frameWidth - 1)) as int;
      top = ((box.top.round() - paddingY).clamp(0, frameHeight - 1)) as int;
      right = ((box.right.round() + paddingX).clamp(0, frameWidth - 1)) as int;
      bottom =
          ((box.bottom.round() + paddingY).clamp(0, frameHeight - 1)) as int;
    }

    if (right <= left || bottom <= top) return const <int>[];

    final samples = <int>[];
    final roiWidth = right - left + 1;
    final roiHeight = bottom - top + 1;
    final stepX = max(1, roiWidth ~/ 28);
    final stepY = max(1, roiHeight ~/ 28);

    for (int y = top; y <= bottom; y += stepY) {
      for (int x = left; x <= right; x += stepX) {
        final offset = (y * bytesPerRow) + (x * pixelStride);
        if (offset < 0 || offset >= bytes.length) continue;

        if (pixelStride >= 4 && offset + 2 < bytes.length) {
          final b = bytes[offset];
          final g = bytes[offset + 1];
          final r = bytes[offset + 2];
          final luminance =
              (0.114 * b + 0.587 * g + 0.299 * r).round().clamp(0, 255);
          samples.add(luminance);
        } else {
          samples.add(bytes[offset]);
        }

        if (samples.length >= 900) {
          return samples;
        }
      }
    }

    return samples;
  }

  bool _isVerifiedMatchResult(dynamic result) {
    if (result is! Map) return false;

    final bool explicitMatch =
        result['IsMatch'] == true || result['Matched'] == true;
    if (explicitMatch) return true;

    final bool successFlag = result['Success'] == true ||
        result['success'] == true ||
        result['SUCCESS'] == true;
    final status =
        (result['Status'] ?? result['status'] ?? '').toString().toLowerCase();
    final message =
        (result['Message'] ?? result['message'] ?? '').toString().toLowerCase();
    final confidence = (result['ConfidenceScore'] as num?)?.toDouble() ?? 0.0;

    // توافق احتياطي مع الردود القديمة: لا نعتبر النجاح صحيحاً إلا إذا
    // كان الرد ناجحاً ورسالة الخادم تؤكد التحقق ودرجة التشابه ضمن الحد المقبول.
    return successFlag &&
        (status == 'success' || status == 'ok' || status.isEmpty) &&
        confidence >= 0.65 &&
        (message.contains('تم التحقق من الوجه بنجاح') ||
            message.contains('verification success'));
  }

  void _smartClose({String reason = 'auto', bool forceSuccess = false}) {
    if (_closeHandled) return;
    _closeHandled = true;
    final bool result = forceSuccess || _completedSuccessfully || _faceMatched;
    final payload = <String, dynamic>{
      'Success': result,
      'Matched': _faceMatched,
      'Completed': _completedSuccessfully,
      'EmployeeNumber': widget.employeeNumber,
      'Reason': reason,
    };
    if (_successfulVerificationPayload != null) {
      payload.addAll(_successfulVerificationPayload!);
    }
    if (kDebugMode) {
      print(
          '🚪 [Verification-SmartClose] محاولة إغلاق شاشة التحقق | result=$result | completed=$_completedSuccessfully | matched=$_faceMatched | reason=$reason | canPop=${Navigator.of(context).canPop()}');
    }
    try {
      final localNavigator = Navigator.of(context);
      final rootNavigator = Navigator.of(context, rootNavigator: true);
      if (localNavigator.canPop()) {
        localNavigator.pop(payload);
      } else if (rootNavigator.canPop()) {
        rootNavigator.pop(payload);
      } else {
        if (kDebugMode) {
          print(
              '🚪 [Verification-SmartClose] لا يوجد Navigator يمكنه pop. سنعتمد على Global Flag فقط.');
        }
      }
    } catch (e) {
      if (kDebugMode)
        print(
            '🚪 [Verification-SmartClose] ❌ استثناء أثناء الإغلاق: $e. الاعتماد على Global Flag Failsafe.');
    }
  }

  void _setupLivenessListeners() {
    _livenessService.statusStream.listen((status) {
      if (!mounted) return;
      setState(() {
        _livenessStatus = status;
      });
      _handleLivenessStatusChange(status);
    });
  }

  void _handleLivenessStatusChange(LivenessStatus status) {
    if (!mounted) return;

    // #region debug-point A:liveness-status
    unawaited(_reportDebugEvent(
      'A',
      'face_verification_screen_mobile.dart:_handleLivenessStatusChange',
      'Liveness status changed',
      data: {
        'status': status.name,
        'isProcessing': _isProcessing,
        'isVerifyingOnServer': _isVerifyingOnServer,
        'controllerExists': _controller != null,
        'controllerInitialized': _controller?.value.isInitialized ?? false,
        'verificationCaptureCompleted': _verificationCaptureCompleted,
      },
    ));
    // #endregion

    switch (status) {
      case LivenessStatus.initializing:
        _borderColor = Colors.blue;
        _statusMessage = _t('liveness_initializing');
        break;
      case LivenessStatus.waitingForFace:
        _borderColor = Colors.blue;
        _statusMessage = _t('liveness_waiting_face');
        _challengeMessage = _getFacePresenceGuidance(_currentFaceCount);
        break;
      case LivenessStatus.challengeInProgress:
        _borderColor = Colors.lightBlueAccent;
        _statusMessage = _lang() == 'ar'
            ? 'جاري فحص الحياة السلبي وتتبع الوجه'
            : 'Passive liveness scan in progress';
        _challengeMessage = _getFacePresenceGuidance(_currentFaceCount);
        break;
      case LivenessStatus.analyzing:
        _borderColor = Colors.purple;
        _challengeMessage = _lang() == 'ar'
            ? 'جاري إنهاء تحليل الهوية ومقاومة الانتحال...'
            : 'Finalizing liveness and anti-spoof analysis...';
        _statusMessage = _t('liveness_analyzing');
        _isProcessing = true;
        break;
      case LivenessStatus.passed:
        _borderColor = Colors.green;
        _lockedAnalysisSnapshot = _livenessService.currentSnapshot;
        _challengeMessage = _lang() == 'ar'
            ? 'تم اجتياز جميع مؤشرات الفحص الحيوي المطلوبة، جاري إرسال التحقق للخادم.'
            : 'All required biometric indicators passed, sending verification request.';
        _statusMessage = _t('liveness_passed');
        // ⚡ تم إزالة _isProcessing=true هنا (تعارض قاتل مع Retry Mechanism!)
        if (kDebugMode) {
          print('✅ [VERIFY-LIVENESS-PASSED] ════════════════════════');
          print(
              '✅ [VERIFY-LIVENESS-PASSED] Status=passed | _isProcessing=$_isProcessing | _isVerifyingOnServer=$_isVerifyingOnServer');
          print(
              '✅ [VERIFY-LIVENESS-PASSED] _controller=${_controller != null ? "EXISTS" : "NULL"} | initialized=${_controller?.value.isInitialized ?? false} | mounted=$mounted');
          print(
              '✅ [VERIFY-LIVENESS-PASSED] بدء سلسلة Retry للاستدعاء (3 محاولات كل 300ms)...');
          print('✅ [VERIFY-LIVENESS-PASSED] ════════════════════════');
        }
        if (_verificationStartRequested ||
            _isVerifyingOnServer ||
            _verificationCaptureCompleted) {
          unawaited(_reportDebugEvent(
            'A',
            'face_verification_screen_mobile.dart:LivenessStatus.passed',
            'Ignored duplicate passed event',
            data: {
              'verificationStartRequested': _verificationStartRequested,
              'isVerifyingOnServer': _isVerifyingOnServer,
              'verificationCaptureCompleted': _verificationCaptureCompleted,
            },
          ));
          break;
        }
        _verificationStartRequested = true;
        // #region debug-point A:passed-trigger
        unawaited(_reportDebugEvent(
          'A',
          'face_verification_screen_mobile.dart:LivenessStatus.passed',
          'Scheduling verification start retry',
          data: {
            'isProcessing': _isProcessing,
            'isVerifyingOnServer': _isVerifyingOnServer,
            'controllerInitialized': _controller?.value.isInitialized ?? false,
            'completedChallenges': _livenessService.completedChallengeCount,
          },
        ));
        // #endregion
        unawaited(_tryStartVerificationWithRetry(maxAttempts: 3, delayMs: 300));
        break;
      case LivenessStatus.spoofDetected:
        _borderColor = Colors.red;
        _challengeMessage = '';
        _statusMessage = _t('liveness_failed_spoof');
        _isProcessing = false;
        _logSecurityEvent('SPOOF_DETECTED');
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) _resetAndStartOver();
        });
        break;
      case LivenessStatus.timeout:
        _borderColor = Colors.orange;
        _challengeMessage = '';
        _statusMessage = _t('liveness_failed_timeout');
        _isProcessing = false;
        Future.delayed(const Duration(seconds: 2), () {
          // ⚡ 2s بدلاً من 3s
          if (mounted) _resetAndStartOver();
        });
        break;
      case LivenessStatus.failed:
        _borderColor = Colors.red;
        _challengeMessage = '';
        _statusMessage = _t('liveness_failed_generic');
        _isProcessing = false;
        Future.delayed(const Duration(seconds: 2), () {
          // ⚡ 2s بدلاً من 3s
          if (mounted) _resetAndStartOver();
        });
        break;
    }
    // ⚡ إزالة setState(() {}) المكرر هنا → كان يسبب إعادة بناء مرتين لكل حدث
  }

  void _logSecurityEvent(String eventType) {
    if (kDebugMode) {
      print(
          '🔴 SECURITY EVENT [$eventType]: Employee: ${widget.employeeNumber}, '
          'Client: ${widget.clientId}, Time: ${DateTime.now().toIso8601String()}');
    }
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    try {
      await _disposeCameraController();

      final attempts = <({ResolutionPreset preset, ImageFormatGroup? format})>[
        (
          preset:
              Platform.isIOS ? ResolutionPreset.high : ResolutionPreset.medium,
          format: Platform.isAndroid
              ? ImageFormatGroup.nv21
              : ImageFormatGroup.bgra8888,
        ),
        (
          preset: ResolutionPreset.medium,
          format: null,
        ),
        (
          preset: ResolutionPreset.low,
          format: null,
        ),
      ];

      Object? lastError;
      for (final attempt in attempts) {
        CameraController? trialController;
        try {
          trialController = _buildCameraController(
            frontCamera,
            preset: attempt.preset,
            formatGroup: attempt.format,
          );
          await trialController.initialize();
          await _configureCameraController(trialController);
          _controller = trialController;
          trialController = null;
          break;
        } catch (e) {
          lastError = e;
          try {
            await trialController?.dispose();
          } catch (_) {}
        }
      }

      if (_controller == null) {
        throw lastError ?? Exception('تعذر تهيئة الكاميرا على هذا الجهاز.');
      }

      // #region debug-point B:camera-init-success
      unawaited(_reportDebugEvent(
        'B',
        'face_verification_screen_mobile.dart:_initializeCamera',
        'Camera initialized successfully',
        data: {
          'platform': Platform.operatingSystem,
          'cameraName': _controller?.description.name,
          'sensorOrientation': _controller?.description.sensorOrientation,
          'previewSize': _controller?.value.previewSize?.toString(),
        },
      ));
      // #endregion

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        await _startFrameStreaming();
      }
    } catch (e) {
      // #region debug-point B:camera-init-failed
      unawaited(_reportDebugEvent(
        'B',
        'face_verification_screen_mobile.dart:_initializeCamera',
        'Camera initialization failed',
        data: {
          'platform': Platform.operatingSystem,
          'error': e.toString().split('\n').first,
        },
      ));
      // #endregion
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _statusMessage = _tParams(
            'camera_start_error_with_error',
            {'error': e.toString()},
          );
        });
      }
    }
  }

  Future<void> _startFrameStreaming() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages ||
        _isStartingImageStream) {
      return;
    }
    _isStartingImageStream = true;
    try {
      await controller.startImageStream(_processCameraImage);
    } finally {
      _isStartingImageStream = false;
    }
  }

  Future<
          ({
            InputImage inputImage,
            InputImageRotation rotation,
            InputImageFormat format,
            int bytesPerRow,
            int planesLength,
          })?>
      _buildMlKitInput(CameraImage image, CameraController controller) async {
    final camera = controller.description;
    final imageSize = Size(image.width.toDouble(), image.height.toDouble());

    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
              InputImageRotation.rotation0deg;
    } else {
      final deviceRotation =
          _cameraOrientationMap[controller.value.deviceOrientation];
      if (deviceRotation == null) {
        return null;
      }
      final adjustedRotation = camera.lensDirection == CameraLensDirection.front
          ? (camera.sensorOrientation + deviceRotation) % 360
          : (camera.sensorOrientation - deviceRotation + 360) % 360;
      rotation = InputImageRotationValue.fromRawValue(adjustedRotation);
      if (rotation == null) {
        return null;
      }
    }

    final inputImageFormat =
        InputImageFormatValue.fromRawValue(image.format.raw);
    if (inputImageFormat == null) {
      return null;
    }

    if (Platform.isIOS && inputImageFormat != InputImageFormat.bgra8888) {
      return null;
    }

    late final Uint8List imageBytes;
    late final InputImageFormat effectiveFormat;
    late final int bytesPerRow;

    if (Platform.isAndroid) {
      if (image.planes.length == 1 &&
          inputImageFormat == InputImageFormat.nv21) {
        imageBytes = image.planes.first.bytes;
        effectiveFormat = InputImageFormat.nv21;
        bytesPerRow = image.width;
      } else if (image.planes.length == 3) {
        imageBytes = _convertYuv420ToNv21(image);
        effectiveFormat = InputImageFormat.nv21;
        bytesPerRow = image.width;
      } else {
        return null;
      }
    } else {
      if (image.planes.length != 1) {
        return null;
      }
      imageBytes = image.planes.first.bytes;
      effectiveFormat = inputImageFormat;
      bytesPerRow = image.planes.first.bytesPerRow;
    }

    final metadata = InputImageMetadata(
      size: imageSize,
      rotation: rotation,
      format: effectiveFormat,
      bytesPerRow: bytesPerRow,
    );

    return (
      inputImage: InputImage.fromBytes(bytes: imageBytes, metadata: metadata),
      rotation: rotation,
      format: effectiveFormat,
      bytesPerRow: bytesPerRow,
      planesLength: image.planes.length,
    );
  }

  Uint8List _convertYuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final nv21 = Uint8List(width * height + (width * height ~/ 2));
    var index = 0;

    for (var row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      nv21.setRange(index, index + width, yPlane.bytes, rowStart);
      index += width;
    }

    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (var row = 0; row < height ~/ 2; row++) {
      final uRowStart = row * uPlane.bytesPerRow;
      final vRowStart = row * vPlane.bytesPerRow;
      for (var col = 0; col < width ~/ 2; col++) {
        nv21[index++] = vPlane.bytes[vRowStart + col * vPixelStride];
        nv21[index++] = uPlane.bytes[uRowStart + col * uPixelStride];
      }
    }

    return nv21;
  }

  Future<void> _processCameraImage(CameraImage image) async {
    // ⚡ نفس الحماية Race Condition للتسجيل (تجنب تعليق الكاميرا):
    // لا نوقف المعالجة عند Status.passed، بل عند اكتمال التقاط الصورة فور نجاح الـ API.
    if (!mounted ||
        _verificationCaptureCompleted ||
        _livenessStatus == LivenessStatus.spoofDetected) {
      return;
    }

    _frameCounter++;
    if (_frameCounter % _processEveryNthFrame != 0) return;

    try {
      final controller = _controller;
      if (controller == null || !controller.value.isInitialized) {
        return;
      }

      final built = await _buildMlKitInput(image, controller);
      if (built == null) {
        if (_frameCounter % 45 == 0) {
          // #region debug-point B:stream-input-unsupported
          unawaited(_reportDebugEvent(
            'B',
            'face_verification_screen_mobile.dart:_processCameraImage',
            'Skipped live frame because ML Kit input was unsupported',
            data: {
              'platform': Platform.operatingSystem,
              'cameraName': controller.description.name,
              'lensDirection': controller.description.lensDirection.name,
              'sensorOrientation': controller.description.sensorOrientation,
              'deviceOrientation': controller.value.deviceOrientation.name,
              'imageWidth': image.width,
              'imageHeight': image.height,
              'planesLength': image.planes.length,
              'formatRaw': image.format.raw,
            },
          ));
          // #endregion
        }
        return;
      }

      final camera = controller.description;
      final imageRotation = built.rotation;
      final inputImageFormat = built.format;
      final bytesPerRow = built.bytesPerRow;
      final Size imageSize =
          Size(image.width.toDouble(), image.height.toDouble());
      final Uint8List singlePlaneBytes = image.planes.first.bytes;
      final faces = await _faceDetector.processImage(built.inputImage);

      Face? currentFace;
      var faceCount = faces.length;
      if (faceCount == 1) {
        currentFace = faces.first;
        _noFaceGraceStreak = 0;
        // ⚡ تخزين آخر إطار صالح كـ Fallback (مثل التسجيل)
        _lastValidFrameBytes = singlePlaneBytes;
        _lastValidFrameSize = imageSize;
        _lastValidFrameRotation = imageRotation;
        _lastValidFace = currentFace;
      } else if (faceCount == 0 &&
          _lastValidFace != null &&
          _noFaceGraceStreak < 2) {
        _noFaceGraceStreak++;
        currentFace = _lastValidFace;
        faceCount = 1;
      } else {
        _noFaceGraceStreak = 0;
        _lastValidFrameBytes = null;
        _lastValidFrameSize = null;
        _lastValidFrameRotation = null;
        _lastValidFace = null;
      }

      final motion = LivenessDetectionService.computeFrameMotion(
        currentFace: currentFace,
        previousFace: _previousTrackedFace,
      );

      if (faceCount != _lastTelemetryFaceCount || _frameCounter % 45 == 0) {
        _lastTelemetryFaceCount = faceCount;
        // #region debug-point A:stream-face-detection
        unawaited(_reportDebugEvent(
          'A',
          'face_verification_screen_mobile.dart:_processCameraImage',
          'Processed live camera frame for face detection',
          data: {
            'platform': Platform.operatingSystem,
            'cameraName': camera.name,
            'lensDirection': camera.lensDirection.name,
            'sensorOrientation': camera.sensorOrientation,
            'deviceOrientation': controller.value.deviceOrientation.name,
            'imageWidth': image.width,
            'imageHeight': image.height,
            'planesLength': image.planes.length,
            'formatRaw': image.format.raw,
            'inputImageFormat': inputImageFormat.name,
            'bytesPerRow': bytesPerRow,
            'faceCount': faceCount,
            'hasCurrentFace': currentFace != null,
            'boundingBoxWidth': currentFace?.boundingBox.width,
            'boundingBoxHeight': currentFace?.boundingBox.height,
          },
        ));
        // #endregion
      }

      final samplePixels = _extractFaceTextureSamples(image, currentFace);
      final noiseVar =
          LivenessDetectionService.computeNoiseVariance(samplePixels);

      _livenessService.processFrame(
        face: currentFace,
        overallMotion: motion,
        noiseVariance: noiseVar,
        imageWidth: imageSize.width,
        imageHeight: imageSize.height,
      );

      if (mounted) {
        setState(() {
          _currentFaceCount = faceCount;
          _currentDetectedFace = currentFace;
          if (_lockedAnalysisSnapshot == null &&
              !_verificationStartRequested &&
              !_isVerifyingOnServer) {
            _analysisSnapshot = _livenessService.currentSnapshot;
            _challengeMessage = _getFacePresenceGuidance(faceCount);
          }
        });
      }

      _previousTrackedFace = currentFace;
    } catch (e) {
      // Suppress frame processing errors to avoid spam
    }
  }

  Future<void> _captureAndVerifyWithLiveness() async {
    final controller = _controller;
    if (!mounted ||
        _isVerifyingOnServer ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    // 🔍 Diagnostics Performance لتتبع زمن كل مرحلة
    final perfTrace = DateTime.now();
    String phase = 'START';
    int verifyAttempt = 0;
    if (kDebugMode) {
      print('⚡ [VERIFY-PERF] ════════════════════════════════════════');
      print(
          '⚡ [VERIFY-PERF] بدء عملية التحقق | Trace: T${perfTrace.millisecondsSinceEpoch.toRadixString(36)} | Emp=${widget.employeeNumber}');
      print('⚡ [VERIFY-PERF] ════════════════════════════════════════');
    }

    setState(() {
      _isVerifyingOnServer = true;
      _isProcessing = true;
      _statusMessage = _t('verifying_face_features');
    });
    // #region debug-point B:capture-enter
    unawaited(_reportDebugEvent(
      'B',
      'face_verification_screen_mobile.dart:_captureAndVerifyWithLiveness',
      'Entered capture and verify',
      data: {
        'controllerInitialized': _controller?.value.isInitialized ?? false,
        'isStreamingImages': _controller?.value.isStreamingImages ?? false,
        'livenessStatus': _livenessStatus.name,
      },
    ));
    // #endregion

    Uint8List? finalImageBytes;
    Face? finalFace;
    String? failReason;

    try {
      if (_currentFaceCount <= 0) {
        _handleFailure(
          _lang() == 'ar'
              ? 'لم يتم اكتشاف وجه، يرجى الوقوف أمام الكاميرا بشكل صحيح داخل الإطار.'
              : 'No face detected. Please stand correctly in front of the camera.',
        );
        return;
      }
      if (_currentFaceCount > 1) {
        _handleFailure(
          _lang() == 'ar'
              ? 'تم اكتشاف أكثر من وجه في الإطار. يجب أن يظهر وجه موظف واحد فقط قبل التحقق.'
              : 'More than one face detected. Only one face is allowed before verification.',
        );
        return;
      }

      // 🔍 المرحلة 1: فحص نتيجة Liveness
      phase = 'CHECK_LIVENESS';
      final livenessResult = _livenessService.getFinalResult();
      if (!livenessResult.passed) {
        if (kDebugMode)
          print(
              '⚡ [VERIFY-PERF] ❌ نتيجة Liveness غير صالحة رغم الحالة passed (تناقض داخلي)');
        _handleLivenessResultFailure(livenessResult);
        return;
      }
      final t1 = DateTime.now().difference(perfTrace).inMilliseconds;
      if (kDebugMode)
        print(
            '⚡ [VERIFY-PERF] (${t1}ms) PHASE 1 OK: Liveness ناجحة | score=${livenessResult.livenessScore.toStringAsFixed(2)} | passed=${livenessResult.passedChecks.length}');

      // 🔍 المرحلة 2: التقاط الصورة أو Fallback بشكل متوافق مع iPhone/Android.
      // على iPhone نفضل JPEG الاستباقية أولاً لأنها أكثر استقراراً من إيقاف البث ثم takePicture.
      // ولا نرسل RAW frames إلى الخادم لأنها ليست صورة JPEG/PNG فعلية وقد تفشل المطابقة.
      phase = 'CAPTURE_IMAGE';
      String fallbackUsed = 'NONE';
      try {
        if (Platform.isIOS) {
          await _ensureFreshIosProactiveCapture();
        }
        if (Platform.isIOS &&
            _lastProactiveCapturedJpg != null &&
            _lastProactiveCapturedFace != null) {
          finalImageBytes = _lastProactiveCapturedJpg!;
          finalFace = _lastProactiveCapturedFace!;
          fallbackUsed = 'IOS_PROACTIVE_JPG_PRIMARY';
          if (kDebugMode) {
            print(
                '⚡ [VERIFY-PERF] استخدام JPEG استباقية كأساس على iPhone (${finalImageBytes!.length ~/ 1024}KB)');
          }
        } else {
          final swCap = Stopwatch()..start();
          final activeController = _controller;
          if (activeController == null ||
              !activeController.value.isInitialized) {
            throw StateError(_lang() == 'ar'
                ? 'تم فقدان اتصال الكاميرا أثناء التحقق. أعد فتح شاشة التحقق.'
                : 'Camera connection was lost during verification. Reopen the verification screen.');
          }
          if (activeController.value.isStreamingImages) {
            await activeController.stopImageStream();
            _streamPausedForStillCapture = true;
          }
          // #region debug-point B:take-picture-before
          unawaited(_reportDebugEvent(
            'B',
            'face_verification_screen_mobile.dart:takePicture-before',
            'Calling takePicture',
            data: {
              'isStreamingImages':
                  _controller?.value.isStreamingImages ?? false,
              'fallbackJpgExists': _lastProactiveCapturedJpg != null,
              'fallbackRawExists': _lastValidFrameBytes != null,
            },
          ));
          // #endregion
          final XFile rawImage = await activeController.takePicture().timeout(
            const Duration(seconds: 8),
            onTimeout: () {
              failReason = 'TIMEOUT_TAKEPICTURE_8S';
              throw TimeoutException(
                  'مهلة التقاط الصورة انتهت (8 ثوانٍ) — سنستخدم آخر صورة JPG محفوظة.');
            },
          );
          final t2a = swCap.elapsedMilliseconds;
          final bytesXFile = await File(rawImage.path)
              .readAsBytes()
              .timeout(const Duration(seconds: 4));
          final t2b = swCap.elapsedMilliseconds;
          final inputImage = InputImage.fromFilePath(rawImage.path);
          final faces = await _faceDetector
              .processImage(inputImage)
              .timeout(const Duration(seconds: 6));
          final t2c = swCap.elapsedMilliseconds;

          if (faces.length == 1) {
            finalImageBytes = bytesXFile;
            finalFace = faces.first;
            fallbackUsed = 'DIRECT';
            if (kDebugMode)
              print(
                  '⚡ [VERIFY-PERF] (${t2c}ms) PHASE 2A OK: takePicture() مباشر + وجه موجود ✅');
            // #region debug-point B:take-picture-success
            unawaited(_reportDebugEvent(
              'B',
              'face_verification_screen_mobile.dart:takePicture-success',
              'Direct takePicture succeeded',
              data: {
                'elapsedMs': t2c,
                'imageKb': finalImageBytes!.length ~/ 1024,
                'faceCount': faces.length,
              },
            ));
            // #endregion
          } else if (faces.length > 1) {
            failReason = 'MULTI_FACE_IN_CAPTURED';
            throw StateError(_lang() == 'ar'
                ? 'تم اكتشاف أكثر من وجه في الصورة. يرجى أن يظهر وجه موظف واحد فقط.'
                : 'More than one face detected in the captured image.');
          } else {
            failReason = 'NO_FACE_IN_CAPTURED';
            throw StateError(_lang() == 'ar'
                ? 'لم يتم اكتشاف وجه في الصورة الملتقطة. يرجى الوقوف أمام الكاميرا بشكل صحيح.'
                : 'No face detected in the captured image.');
          }
        }
      } on StateError {
        rethrow;
      } catch (capErr) {
        if (kDebugMode)
          print(
              '⚡ [VERIFY-PERF] ⚠️ المرحلة 2A فشلت ($failReason): $capErr → البحث عن Fallback...');
        // #region debug-point B:take-picture-failed
        unawaited(_reportDebugEvent(
          'B',
          'face_verification_screen_mobile.dart:takePicture-failed',
          'Direct capture failed, moving to fallback',
          data: {
            'failReason': failReason,
            'error': capErr.toString().split('\n').first,
            'fallbackJpgExists': _lastProactiveCapturedJpg != null,
            'fallbackRawExists': _lastValidFrameBytes != null,
          },
        ));
        // #endregion
        // ⚡ Fallback 1: صورة JPG استباقية (الأفضل أماناً)
        if (_lastProactiveCapturedJpg != null &&
            _lastProactiveCapturedFace != null) {
          final t2fb1 = DateTime.now().difference(perfTrace).inMilliseconds;
          finalImageBytes = _lastProactiveCapturedJpg!;
          finalFace = _lastProactiveCapturedFace!;
          fallbackUsed = 'PROACTIVE_JPG';
          if (kDebugMode)
            print(
                '⚡ [VERIFY-PERF] (${t2fb1}ms) PHASE 2B OK: Fallback 1 → صورة JPG استباقية (حجم=${finalImageBytes!.length ~/ 1024}KB) ✅');
        } else {
          throw StateError(_lang() == 'ar'
              ? 'تعذر الحصول على صورة وجه صالحة من الكاميرا. أعد المحاولة مع إبقاء الوجه ثابتاً داخل الإطار.'
              : 'Unable to obtain a valid face image from the camera. Try again while keeping your face steady inside the frame.');
        }
      }
      if (finalImageBytes == null || finalFace == null)
        throw Exception('فشل الحصول على صورة وجه صالحة.');

      // 🔍 المرحلة 3: فحص زوايا الرأس والعيون
      phase = 'VALIDATE_POSE';
      double headY = finalFace!.headEulerAngleY ?? 0;
      double headX = finalFace!.headEulerAngleX ?? 0;
      if (headY.abs() > 30 || headX.abs() > 30) {
        throw StateError(_t('look_straight_no_tilt'));
      }
      if (finalFace!.leftEyeOpenProbability != null &&
          finalFace!.leftEyeOpenProbability! < 0.12) {
        throw StateError(_t('open_eyes_clearly'));
      }
      final t3 = DateTime.now().difference(perfTrace).inMilliseconds;
      if (kDebugMode)
        print(
            '⚡ [VERIFY-PERF] (${t3}ms) PHASE 3 OK: زوايا الرأس والعيون صالحة | headY=${headY.toStringAsFixed(1)}° headX=${headX.toStringAsFixed(1)}°');

      // 🔍 المرحلة 4: Base64 + Metadata (إصلاح sessionDuration + معلومات Fallback)
      phase = 'BASE64_ENCODE';
      final base64Image = base64Encode(finalImageBytes!);
      final snapshotForVerification = _displaySnapshot;
      final livenessMetadata = {
        'livenessScore': livenessResult.livenessScore,
        'spoofRisk': livenessResult.spoofRisk,
        'passedChecks': livenessResult.passedChecks,
        'challengesCompleted': _livenessService.completedChallengeCount,
        'passiveAnalysis': {
          'trackingScore': snapshotForVerification.trackingScore,
          'poseScore': snapshotForVerification.poseScore,
          'eyeActivityScore': snapshotForVerification.eyeActivityScore,
          'breathingScore': snapshotForVerification.breathingScore,
          'textureScore': snapshotForVerification.textureScore,
          'landmarkScore': snapshotForVerification.landmarkScore,
          'antiSpoofScore': snapshotForVerification.antiSpoofScore,
          'overallScore': snapshotForVerification.overallScore,
          'completedSignals': snapshotForVerification.completedSignals,
          'requiredSignals': snapshotForVerification.requiredSignals,
        },
        // ⚡ إصلاح حساب مدة الجلسة: من وقت بدء الجلسة الفعلي
        'sessionDurationSec':
            DateTime.now().difference(_sessionStartTime).inSeconds,
        'verificationTimestamp': DateTime.now().toIso8601String(),
        // ⚡ معلومات مصدر الصورة للتشخيص
        'imageSource': fallbackUsed,
        'capturedFallbackUsed': fallbackUsed != 'DIRECT',
        'platform': Platform.operatingSystem,
      };
      final t4 = DateTime.now().difference(perfTrace).inMilliseconds;
      if (kDebugMode) {
        print(
            '⚡ [VERIFY-PERF] (${t4}ms) PHASE 4 OK: Base64 + Metadata | حجم الصورة=${finalImageBytes!.length ~/ 1024}KB');
      }
      // #region debug-point A:verification-payload
      unawaited(_reportDebugEvent(
        'A',
        'face_verification_screen_mobile.dart:_captureAndVerifyWithLiveness',
        'Prepared verification payload for server',
        data: {
          'platform': Platform.operatingSystem,
          'imageSource': fallbackUsed,
          'capturedFallbackUsed': fallbackUsed != 'DIRECT',
          'imageKb': finalImageBytes!.length ~/ 1024,
          'headY': headY,
          'headX': headX,
          'livenessScore': livenessResult.livenessScore,
          'completedSignals': snapshotForVerification.completedSignals,
          'requiredSignals': snapshotForVerification.requiredSignals,
        },
      ));
      // #endregion

      // 🔍 المرحلة 5: Retry ذكي لإرسال التحقق (3 محاولات بدون إعادة Liveness!)
      phase = 'VERIFY_API_SEND';
      const maxAttempts = 3;
      Map<String, dynamic>? finalResult;
      String? lastApiErr;

      for (verifyAttempt = 1; verifyAttempt <= maxAttempts; verifyAttempt++) {
        try {
          if (kDebugMode)
            print(
                '⚡ [VERIFY-PERF] 🔄 محاولة التحقق $verifyAttempt/$maxAttempts (NEW FLOW: مطابقة مع الصورة المخزنة في Users_Employees)...');
          final swApi = Stopwatch()..start();
          // 🆕 استخدام الـ API الجديد: verifyFaceWithStoredImage → يقوم بالآتي على السيرفر:
          //    1. سحب صورة الوجه المحفوظة من جدول Users_Employees
          //    2. مطابقة الوجه الملتقط حالياً (مع نتيجة Liveness) مع الصورة المحفوظة
          //    3. إرجاع Match/NoMatch + درجة التشابه
          final r = await FaceApiService.verifyFaceWithStoredImage(
            clientId: widget.clientId,
            employeeNumber: widget.employeeNumber,
            imageBase64: base64Image,
            deviceInfo: jsonEncode(livenessMetadata),
            livenessScore: livenessResult.livenessScore,
            challengesCompleted: _livenessService.completedChallengeCount,
            spoofRisk: livenessResult.spoofRisk,
            timeout: const Duration(seconds: 45),
          );
          final t5sub = swApi.elapsedMilliseconds;
          finalResult = r;
          // #region debug-point E:verify-api-result
          unawaited(_reportDebugEvent(
            'E',
            'face_verification_screen_mobile.dart:verify-api-result',
            'Verify API returned response',
            data: {
              'attempt': verifyAttempt,
              'elapsedMs': t5sub,
              'success': _isVerifiedMatchResult(r),
              'message': r['Message']?.toString(),
              'statusCode': r['StatusCode'] ?? r['statusCode'],
              'isMatch': r['IsMatch'] ?? r['Matched'],
              'confidenceScore': r['ConfidenceScore'],
            },
          ));
          // #endregion
          if (_isVerifiedMatchResult(r)) {
            if (kDebugMode)
              print(
                  '⚡ [VERIFY-PERF] (${t5sub}ms) PHASE 5 OK: نجح التحقق في المحاولة $verifyAttempt');
            lastApiErr = null;
            break;
          } else {
            lastApiErr = r['Message'] ?? 'فشل التحقق غير معروف';
            if (kDebugMode)
              print(
                  '⚡ [VERIFY-PERF] ⚠️ رفض السيرفر محاولة $verifyAttempt: $lastApiErr');
            // ⚡ إصلاح منطق التوقف: توسيع القائمة (نفس منطق التسجيل)
            final errLower = lastApiErr!.toLowerCase();
            final logicalStopKeywords = [
              'غير موجود',
              'غير مفعل',
              'الموظف',
              'بصمة',
              'مسجلة',
              'face template',
              'غير واضح',
              'quality',
              'جودة',
              'لا يوجد وجه',
              'no face',
              'detect',
              'لا تتطابق',
              'mismatch',
              'not match',
              'غير مصرح',
              'unauthorized',
              'permission',
              'القاعدة',
              'database',
              'duplicate',
              'invalid',
              'خطأ في',
              'الرجاء',
              'محظور',
              'blocked',
              'suspended',
            ];
            bool shouldStop = logicalStopKeywords.any((k) =>
                lastApiErr!.contains(k) || errLower.contains(k.toLowerCase()));
            if (shouldStop) {
              if (kDebugMode)
                print('⚡ [VERIFY-PERF] 🛑 توقف Retry (خطأ منطقي): $lastApiErr');
              break;
            }
          }
        } catch (apiErr) {
          lastApiErr = apiErr.toString();
          if (kDebugMode)
            print(
                '⚡ [VERIFY-PERF] ❌ استثناء محاولة $verifyAttempt: $lastApiErr');
        }
        if (verifyAttempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 600 * verifyAttempt));
        }
      }

      // 🔍 المرحلة 6: الفحص النهائي + إغلاق الشاشة
      phase = 'FINALIZE';
      _verificationCaptureCompleted = true; // ⚡ الآن فقط نوقف معالجة الإطارات

      // Diagnostics كامل للرد (حافظ على التشخيص الأصلي!)
      if (kDebugMode && finalResult != null) {
        print('🔎 DIAGNOSTIC VerifyFace API Response:');
        print(
            '   • Keys = ${finalResult is Map ? finalResult.keys.toList() : "Not a Map: ${finalResult.runtimeType}"}');
        if (finalResult is Map) {
          finalResult.forEach(
              (k, v) => print('   • [$k] => ${v.runtimeType.toString()}: $v'));
        }
        print(
            '   • _isVerifiedMatchResult(result) = ${_isVerifiedMatchResult(finalResult)}');
      }

      if (finalResult != null && _isVerifiedMatchResult(finalResult)) {
        // الفائقة الأهمية: العلم العالمي أولاً!
        FaceApiService.markLastFaceSessionSuccessful(
          employeeNumber: widget.employeeNumber,
          sessionKind: 'verification',
        );
        _completedSuccessfully = true;
        _faceMatched = true;
        _successfulVerificationPayload = {
          'Verified': true,
          'VerificationAtUtc': DateTime.now().toUtc().toIso8601String(),
          'ConfidenceScore':
              (finalResult!['ConfidenceScore'] as num?)?.toDouble(),
          'LivenessScore': (finalResult!['LivenessScore'] as num?)?.toDouble(),
          'ServerMessage': finalResult!['Message']?.toString(),
          'VerificationContext': 'ATTENDANCE_CHECKPOINT',
        };
        final totalMs = DateTime.now().difference(perfTrace).inMilliseconds;
        if (kDebugMode) {
          final isMatch = (finalResult!['IsMatch'] == true) ||
              (finalResult!['Matched'] == true) ||
              (finalResult!['Success'] == true);
          print('✅ DIAGNOSTIC [VERIFY-SUCCESS] ═══════════════════');
          print(
              '✅  الإجمالي: ${totalMs}ms | المحاولات: $verifyAttempt/$maxAttempts | Match=$isMatch');
          print('✅  رسالة السيرفر: ${finalResult!['Message'] ?? '---'}');
          print(
              '✅  سيتم الإرجاع الآن فوراً عبر _smartClose + Global Flag مُفعّل.');
          print('✅ DIAGNOSTIC [VERIFY-SUCCESS] ═══════════════════');
        }
        if (mounted) {
          // #region debug-point C:verification-success
          unawaited(_reportDebugEvent(
            'C',
            'face_verification_screen_mobile.dart:_captureAndVerifyWithLiveness',
            'Verification flow finished successfully',
            data: {
              'platform': Platform.operatingSystem,
              'confidenceScore': finalResult!['ConfidenceScore'],
              'livenessScore': finalResult!['LivenessScore'],
              'serverMessage': finalResult!['Message']?.toString(),
              'reason': 'verify-success',
            },
          ));
          // #endregion
          setState(() {
            _borderColor = Colors.green;
            _statusMessage = _t('verification_success');
            _instructionMessage = _t('identity_matched');
            _isProcessing = false;
            _isVerifyingOnServer = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              if (mounted)
                _smartClose(reason: 'verify-success', forceSuccess: true);
            } catch (e) {
              if (kDebugMode)
                print(
                    '⚠️ فشل _smartClose في التحقق (سنعتمد على Global Flag): $e');
            }
          });
        }
      } else {
        final msg = lastApiErr ?? _t('verification_failed');
        // #region debug-point E:verification-failed-final
        unawaited(_reportDebugEvent(
          'E',
          'face_verification_screen_mobile.dart:_captureAndVerifyWithLiveness',
          'Verification flow ended without accepted match',
          data: {
            'platform': Platform.operatingSystem,
            'lastApiError': lastApiErr,
            'finalResultType': finalResult.runtimeType.toString(),
            'finalResultValue': finalResult?.toString(),
            'verifyAttempt': verifyAttempt,
          },
        ));
        // #endregion
        if (kDebugMode) {
          print(
              '❌ [VERIFY-PERF] فشل نهائي بعد $maxAttempts محاولات. السبب الأخير: $msg');
          print('❌ [VERIFY-PERF] آخر مرحلة ناجحة قبل الفشل: $phase');
        }
        _handleFailure(msg);
      }
    } catch (e, stack) {
      if (kDebugMode) {
        final msTotal = DateTime.now().difference(perfTrace).inMilliseconds;
        print(
            '❌❌❌ [VERIFY-PERF] استثناء فادح (${msTotal}ms) | آخر مرحلة ناجحة: $phase | المحاولة $verifyAttempt');
        print('❌❌❌ [VERIFY-PERF] الخطأ: $e');
        print('❌❌❌ [VERIFY-PERF] Stack: $stack');
      }
      _verificationCaptureCompleted = false;
      _verificationStartRequested = false;
      if (e is TimeoutException) {
        _handleFailure(
          _lang() == 'ar'
              ? 'استغرق الخادم وقتاً أطول من المتوقع أثناء التحقق من الوجه. تأكد أن خدمة التعرف على الوجه وواجهة الـ API تعملان ثم أعد المحاولة.'
              : 'The server took too long while verifying the face. Make sure the face engine and API are running, then try again.',
        );
      } else if (e is StateError) {
        _handleFailure(e.message);
      } else {
        _handleFailure(_tParams('connection_error_with_error',
            {'error': e.toString().split('\n').first}));
      }
    }
  }

  /// ⚡ حماية جديدة: Retry Mechanism لبدء عملية التحقق بعد Status.passed.
  /// تحاول استدعاء _captureAndVerifyWithLiveness عدة مرات إذا فشلت الشروط الأولية،
  /// حتى نتجنب تعليق الشاشة في حالة "2 من 2" للأبد بسبب Race Condition نادر.
  Future<void> _tryStartVerificationWithRetry({
    required int maxAttempts,
    required int delayMs,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      if (!mounted) return;
      final String reason1 =
          _isVerifyingOnServer ? "_isVerifyingOnServer=true" : "✓";
      final String reason2 = _controller == null ? "controller=NULL" : "✓";
      final String reason3 =
          (_controller != null && !_controller!.value.isInitialized)
              ? "controller not init"
              : "✓";
      final String reasonsFailed =
          [reason1, reason2, reason3].where((e) => e != "✓").join(", ");
      if (kDebugMode) {
        print(
            '🔄 [VERIFY-START] محاولة $attempt/$maxAttempts: الفشل المحتمل=[$reasonsFailed]');
      }
      // #region debug-point A:start-retry-attempt
      unawaited(_reportDebugEvent(
        'A',
        'face_verification_screen_mobile.dart:_tryStartVerificationWithRetry',
        'Verification start retry tick',
        data: {
          'attempt': attempt,
          'maxAttempts': maxAttempts,
          'reasonsFailed': reasonsFailed,
          'isVerifyingOnServer': _isVerifyingOnServer,
          'controllerInitialized': _controller?.value.isInitialized ?? false,
          'isStreamingImages': _controller?.value.isStreamingImages ?? false,
        },
      ));
      // #endregion

      // 🚨 تم إزالة _isProcessing من الشروط (تناقض قاتل مع Status.passed!)
      if (!_isVerifyingOnServer &&
          _controller != null &&
          _controller!.value.isInitialized) {
        if (kDebugMode)
          print(
              '🔄 [VERIFY-START-$attempt] ✅ جميع الشروط مستوفاة → بدء التحقق فوراً');
        // #region debug-point A:start-retry-success
        unawaited(_reportDebugEvent(
          'A',
          'face_verification_screen_mobile.dart:_tryStartVerificationWithRetry',
          'Verification start conditions satisfied',
          data: {
            'attempt': attempt,
          },
        ));
        // #endregion
        await _captureAndVerifyWithLiveness();
        return;
      }

      if (kDebugMode) {
        print(
            '🔄 [VERIFY-START-$attempt] ⚠️ فشلت الشروط: [$reasonsFailed] → انتظار ${delayMs}ms ثم إعادة المحاولة');
      }
      await Future.delayed(Duration(milliseconds: delayMs));
    }
    if (kDebugMode) {
      print(
          '❌ [VERIFY-START] ❌ فشلت جميع $maxAttempts محاولات بدء التحقق → إعادة البدء من الصفر مع رسالة خطأ...');
    }
    if (mounted) {
      // #region debug-point A:start-retry-exhausted
      unawaited(_reportDebugEvent(
        'A',
        'face_verification_screen_mobile.dart:_tryStartVerificationWithRetry',
        'Verification start retries exhausted',
        data: {
          'maxAttempts': maxAttempts,
          'isVerifyingOnServer': _isVerifyingOnServer,
          'controllerExists': _controller != null,
          'controllerInitialized': _controller?.value.isInitialized ?? false,
        },
      ));
      // #endregion
      setState(() {
        _statusMessage =
            'تعطل بدء عملية التحقق من البصمة. تم إعادة بدء الفحص تلقائياً...';
        _borderColor = Colors.redAccent;
        _isProcessing = false;
        _isVerifyingOnServer = false;
      });
      _verificationStartRequested = false;
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _resetAndStartOver();
      });
    }
  }

  void _handleLivenessResultFailure(LivenessResult result) {
    setState(() {
      _isProcessing = false;
      _isVerifyingOnServer = false;
      _borderColor = Colors.red;
      _statusMessage = result.message ?? _t('liveness_failed_generic');
      _instructionMessage = _t('try_again');
    });
    _verificationStartRequested = false;
    _logSecurityEvent('LIVENESS_FAIL_${result.status.name}');
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_faceMatched) _resetAndStartOver();
    });
  }

  void _handleFailure(String message) {
    if (!mounted) return;
    // #region debug-point D:handle-failure
    unawaited(_reportDebugEvent(
      'D',
      'face_verification_screen_mobile.dart:_handleFailure',
      'Verification flow entered failure state',
      data: {
        'message': message,
        'currentFaceCount': _currentFaceCount,
        'livenessStatus': _livenessStatus.name,
        'isVerifyingOnServer': _isVerifyingOnServer,
        'verificationCaptureCompleted': _verificationCaptureCompleted,
      },
    ));
    // #endregion
    setState(() {
      _borderColor = Colors.red;
      _statusMessage = message;
      _instructionMessage = _t('try_again');
      _isProcessing = false;
      _isVerifyingOnServer = false;
    });
    _verificationStartRequested = false;
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_faceMatched) {
        _resetAndStartOver();
      }
    });
  }

  void _resetAndStartOver() {
    if (!mounted) return;
    // #region debug-point C:reset-start-over
    unawaited(_reportDebugEvent(
      'C',
      'face_verification_screen_mobile.dart:_resetAndStartOver',
      'Resetting verification flow to initial state',
      data: {
        'faceMatched': _faceMatched,
        'currentFaceCount': _currentFaceCount,
        'verificationCaptureCompleted': _verificationCaptureCompleted,
        'verificationStartRequested': _verificationStartRequested,
      },
    ));
    // #endregion
    setState(() {
      _isProcessing = false;
      _isVerifyingOnServer = false;
      _previousTrackedFace = null;
      _frameCounter = 0;
      _verificationCaptureCompleted =
          false; // ⚡ إعادة تفعيل معالجة الإطارات عند إعادة البدء
      _verificationStartRequested = false;
      _closeHandled = false;
      _successfulVerificationPayload = null;
      _lockedAnalysisSnapshot = null;
      _currentDetectedFace = null;
      _currentFaceCount = 0;
      _analysisSnapshot = const PassiveLivenessSnapshot.empty();
    });
    _livenessService.initialize();
    unawaited(_resumeImageStreamIfNeeded());
  }

  Future<void> _resetFace() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = _t('resetting_face');
    });

    try {
      final result = await FaceApiService.resetFace(
          widget.clientId, widget.employeeNumber);
      if (result['Success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_t('face_reset_success'))),
          );
          Navigator.pop(context, false);
        }
      } else {
        _handleFailure(result['Message'] ?? _t('face_reset_failed'));
      }
    } catch (e) {
      _handleFailure(_tParams('error_with_error', {'error': e.toString()}));
    }
  }

  Widget _buildMetricChip(String label, double value, {required bool passed}) {
    final normalized = value.clamp(0.0, 1.0);
    final Color chipColor = passed
        ? Colors.greenAccent
        : normalized >= 0.5
            ? Colors.orangeAccent
            : Colors.redAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: chipColor.withOpacity(0.8)),
      ),
      child: Text(
        '${passed ? "✓ " : ""}$label ${(normalized * 100).round()}%',
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
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
    final displaySnapshot = _displaySnapshot;

    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _smartClose();
      },
      child: Scaffold(
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
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(child: CameraPreview(controller)),
                          IgnorePointer(
                            child: CustomPaint(
                              painter: _FaceGuidePainter(
                                faceDetected: _currentDetectedFace != null,
                                readiness: displaySnapshot.overallScore,
                                color: _borderColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 60,
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
                    _t('liveness_title'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            if (_challengeMessage.isNotEmpty)
              Positioned(
                top: 120,
                left: 16,
                right: 16,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _borderColor.withOpacity(0.95),
                          _borderColor.withOpacity(0.75),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: _borderColor.withOpacity(0.4),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(0.6),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _challengeMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 205,
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: _displaySignalProgress,
                      minHeight: 10,
                      backgroundColor: Colors.white24,
                      valueColor: AlwaysStoppedAnimation<Color>(_borderColor),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _buildSignalSummaryText(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _buildOverallSnapshotText(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildMetricChip(
                        _lang() == 'ar' ? 'التموضع' : 'Tracking',
                        displaySnapshot.trackingScore,
                        passed: displaySnapshot.trackingPassed,
                      ),
                      _buildMetricChip(
                        _lang() == 'ar' ? 'الوضعية' : 'Pose',
                        displaySnapshot.poseScore,
                        passed: displaySnapshot.posePassed,
                      ),
                      _buildMetricChip(
                        _lang() == 'ar' ? 'العينان' : 'Eyes',
                        displaySnapshot.eyeActivityScore,
                        passed: displaySnapshot.eyeActivityPassed,
                      ),
                      _buildMetricChip(
                        _lang() == 'ar' ? 'التنفس' : 'Breath',
                        displaySnapshot.breathingScore,
                        passed: displaySnapshot.breathingPassed,
                      ),
                      _buildMetricChip(
                        _lang() == 'ar' ? 'النسيج' : 'Texture',
                        displaySnapshot.textureScore,
                        passed: displaySnapshot.texturePassed,
                      ),
                      _buildMetricChip(
                        _lang() == 'ar' ? 'المعالم' : 'Landmarks',
                        displaySnapshot.landmarkScore,
                        passed: displaySnapshot.landmarkPassed,
                      ),
                      _buildMetricChip(
                        _lang() == 'ar' ? 'مقاومة الانتحال' : 'Anti-spoof',
                        displaySnapshot.antiSpoofScore,
                        passed: displaySnapshot.antiSpoofPassed,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    if (_isProcessing || _isVerifyingOnServer)
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
                    const SizedBox(height: 6),
                    if (_instructionMessage.isNotEmpty &&
                        !_isProcessing &&
                        !_isVerifyingOnServer)
                      Text(
                        _instructionMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    if (!_isProcessing &&
                        !_isVerifyingOnServer &&
                        !_faceMatched) ...[
                      const SizedBox(height: 26),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _resetAndStartOver,
                            icon: const Icon(Icons.refresh),
                            label: Text(_t('retry')),
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
                              label: Text(_t('reset')),
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
                onPressed: _smartClose,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaceGuidePainter extends CustomPainter {
  final bool faceDetected;
  final double readiness;
  final Color color;

  _FaceGuidePainter({
    required this.faceDetected,
    required this.readiness,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final frameWidth = size.width * 0.64;
    final frameHeight = size.height * 0.42;
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.47),
      width: frameWidth,
      height: frameHeight,
    );

    final glowStrength = readiness.clamp(0.18, 1.0);
    final framePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = faceDetected ? 4.0 : 3.0;
    final glowPaint = Paint()
      ..color = color.withOpacity(0.12 + (glowStrength * 0.12))
      ..style = PaintingStyle.fill;
    final cornerPaint = Paint()
      ..color = color.withOpacity(0.95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.inflate(10), const Radius.circular(28)),
      glowPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(24)),
      framePaint,
    );

    const double cornerLen = 34;
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];
    for (final corner in corners) {
      final bool isLeft = corner.dx == rect.left;
      final bool isTop = corner.dy == rect.top;
      final path = Path()
        ..moveTo(corner.dx, corner.dy + (isTop ? cornerLen : -cornerLen))
        ..lineTo(corner.dx, corner.dy)
        ..lineTo(corner.dx + (isLeft ? cornerLen : -cornerLen), corner.dy);
      canvas.drawPath(path, cornerPaint);
    }

    if (faceDetected) {
      final scannerPaint = Paint()
        ..color = color.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      final scannerY =
          rect.top + ((rect.height - 8) * readiness.clamp(0.0, 1.0));
      canvas.drawLine(
        Offset(rect.left + 12, scannerY),
        Offset(rect.right - 12, scannerY),
        scannerPaint,
      );

      final dotPaint = Paint()
        ..color = Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(rect.center.dx, rect.top - 12),
        4.5,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FaceGuidePainter oldDelegate) {
    return oldDelegate.faceDetected != faceDetected ||
        oldDelegate.readiness != readiness ||
        oldDelegate.color != color;
  }
}
