import 'dart:async';
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum LivenessChallengeType {
  blink,
  smile,
  mouthOpen,
  headTiltLeft,
  headTiltRight,
  headTiltUp,
  headTiltDown,
}

enum LivenessStatus {
  initializing,
  waitingForFace,
  challengeInProgress,
  analyzing,
  passed,
  failed,
  spoofDetected,
  timeout,
}

class LivenessFrameData {
  final DateTime timestamp;
  final Face? face;
  final double overallMotion;
  final double noiseVariance;
  final double avgEyeOpen;
  final double yaw;
  final double pitch;
  final double faceCenterX;
  final double faceCenterY;
  final double faceAreaRatio;
  final double breathingSignal;
  final double landmarkCoverage;

  LivenessFrameData({
    required this.timestamp,
    required this.face,
    required this.overallMotion,
    required this.noiseVariance,
    required this.avgEyeOpen,
    required this.yaw,
    required this.pitch,
    required this.faceCenterX,
    required this.faceCenterY,
    required this.faceAreaRatio,
    required this.breathingSignal,
    required this.landmarkCoverage,
  });
}

class LivenessChallenge {
  final LivenessChallengeType type;
  final DateTime startTime;
  final Duration timeLimit;
  bool completed;
  bool failed;

  LivenessChallenge({
    required this.type,
    required this.startTime,
    this.timeLimit = const Duration(seconds: 8),
    this.completed = false,
    this.failed = false,
  });
}

class LivenessResult {
  final bool passed;
  final LivenessStatus status;
  final String? message;
  final double livenessScore;
  final double spoofRisk;
  final List<String> passedChecks;
  final List<String> failedChecks;

  LivenessResult({
    required this.passed,
    required this.status,
    this.message,
    required this.livenessScore,
    required this.spoofRisk,
    required this.passedChecks,
    required this.failedChecks,
  });

  factory LivenessResult.passed({
    required double score,
    required List<String> checks,
  }) =>
      LivenessResult(
        passed: true,
        status: LivenessStatus.passed,
        livenessScore: score,
        spoofRisk: 1.0 - score,
        passedChecks: checks,
        failedChecks: const [],
        message: 'Passive liveness verification passed',
      );

  factory LivenessResult.failed({
    required LivenessStatus status,
    required String message,
    required double spoofRisk,
    required List<String> failedChecks,
    required List<String> passedChecks,
  }) =>
      LivenessResult(
        passed: false,
        status: status,
        message: message,
        livenessScore: (1.0 - spoofRisk).clamp(0.0, 1.0),
        spoofRisk: spoofRisk,
        passedChecks: passedChecks,
        failedChecks: failedChecks,
      );
}

class PassiveLivenessSnapshot {
  final bool faceDetected;
  final double trackingScore;
  final bool trackingPassed;
  final double poseScore;
  final bool posePassed;
  final double eyeActivityScore;
  final bool eyeActivityPassed;
  final double breathingScore;
  final bool breathingPassed;
  final double textureScore;
  final bool texturePassed;
  final double antiSpoofScore;
  final bool antiSpoofPassed;
  final double landmarkScore;
  final bool landmarkPassed;
  final double overallScore;
  final int completedSignals;
  final int requiredSignals;
  final int totalSignals;
  final String guidanceAr;
  final String guidanceEn;

  const PassiveLivenessSnapshot({
    required this.faceDetected,
    required this.trackingScore,
    required this.trackingPassed,
    required this.poseScore,
    required this.posePassed,
    required this.eyeActivityScore,
    required this.eyeActivityPassed,
    required this.breathingScore,
    required this.breathingPassed,
    required this.textureScore,
    required this.texturePassed,
    required this.antiSpoofScore,
    required this.antiSpoofPassed,
    required this.landmarkScore,
    required this.landmarkPassed,
    required this.overallScore,
    required this.completedSignals,
    required this.requiredSignals,
    required this.totalSignals,
    required this.guidanceAr,
    required this.guidanceEn,
  });

  const PassiveLivenessSnapshot.empty()
      : faceDetected = false,
        trackingScore = 0.0,
        trackingPassed = false,
        poseScore = 0.0,
        posePassed = false,
        eyeActivityScore = 0.0,
        eyeActivityPassed = false,
        breathingScore = 0.0,
        breathingPassed = false,
        textureScore = 0.0,
        texturePassed = false,
        antiSpoofScore = 0.0,
        antiSpoofPassed = false,
        landmarkScore = 0.0,
        landmarkPassed = false,
        overallScore = 0.0,
        completedSignals = 0,
        requiredSignals = 7,
        totalSignals = 7,
        guidanceAr = 'ضع وجهك داخل الإطار وحافظ على نظرة طبيعية.',
        guidanceEn =
            'Place your face inside the frame and keep a natural look.';
}

class LivenessDetectionService {
  static const int _totalSignals = 7;
  static const int _minFramesForAnalysis = 12;
  static const int _maxFramesBuffer = 72;
  static const int _requiredSignals = _totalSignals;
  static const double _blinkThresholdLow = 0.33;
  static const double _blinkThresholdHigh = 0.72;
  static const double _maxYawDegrees = 30.0;
  static const double _maxPitchDegrees = 25.0;
  static const double _spoofRejectThreshold = 0.74;

  final List<LivenessFrameData> _frameBuffer = [];
  final List<double> _depthRiskHistory = [];
  final List<String> _completedSignalKeys = [];
  final List<String> _passedChecks = [];
  final List<String> _failedChecks = [];

  DateTime? _sessionStart;
  final Duration _maxSessionDuration = const Duration(seconds: 30);
  LivenessStatus _currentStatus = LivenessStatus.initializing;
  PassiveLivenessSnapshot _currentSnapshot =
      const PassiveLivenessSnapshot.empty();

  bool _wasBlinking = false;
  int _blinkCount = 0;
  double _lastDepthSpoofRisk = 0.0;

  final StreamController<LivenessStatus> _statusController =
      StreamController<LivenessStatus>.broadcast();
  final StreamController<LivenessChallenge> _challengeController =
      StreamController<LivenessChallenge>.broadcast();
  final StreamController<double> _progressController =
      StreamController<double>.broadcast();

  Stream<LivenessStatus> get statusStream => _statusController.stream;
  Stream<LivenessChallenge> get challengeStream => _challengeController.stream;
  Stream<double> get progressStream => _progressController.stream;

  LivenessStatus get currentStatus => _currentStatus;
  LivenessChallenge? get currentChallenge => null;
  List<LivenessChallengeType> get completedChallenges =>
      LivenessChallengeType.values.take(_completedSignalKeys.length).toList();
  int get requiredChallenges => _requiredSignals;
  int get completedChallengeCount => _completedSignalKeys.length;
  double get lastDepthSpoofRisk => _lastDepthSpoofRisk;
  int get depthFrameCount => _depthRiskHistory.length;
  double get averageDepthSpoofRisk {
    if (_depthRiskHistory.isEmpty) return 0.5;
    return (_depthRiskHistory.reduce((a, b) => a + b) /
            _depthRiskHistory.length)
        .clamp(0.0, 1.0);
  }

  PassiveLivenessSnapshot get currentSnapshot => _currentSnapshot;

  void initialize({int requiredChallenges = 0}) {
    _frameBuffer.clear();
    _depthRiskHistory.clear();
    _completedSignalKeys.clear();
    _passedChecks.clear();
    _failedChecks.clear();
    _sessionStart = DateTime.now();
    _currentStatus = LivenessStatus.waitingForFace;
    _currentSnapshot = const PassiveLivenessSnapshot.empty();
    _wasBlinking = false;
    _blinkCount = 0;
    _lastDepthSpoofRisk = 0.0;
    _emitStatus();
    _emitProgress();
  }

  void _emitStatus() {
    if (!_statusController.isClosed) {
      _statusController.add(_currentStatus);
    }
  }

  void _emitProgress() {
    if (!_progressController.isClosed) {
      _progressController.add(
          (_completedSignalKeys.length / _requiredSignals).clamp(0.0, 1.0));
    }
  }

  void processFrame({
    required Face? face,
    required double overallMotion,
    required double noiseVariance,
    double imageWidth = 1.0,
    double imageHeight = 1.0,
  }) {
    if (_sessionStart != null &&
        DateTime.now().difference(_sessionStart!) > _maxSessionDuration) {
      _currentStatus = LivenessStatus.timeout;
      _emitStatus();
      return;
    }

    if (face == null) {
      _frameBuffer.add(LivenessFrameData(
        timestamp: DateTime.now(),
        face: null,
        overallMotion: overallMotion,
        noiseVariance: noiseVariance,
        avgEyeOpen: 0.0,
        yaw: 0.0,
        pitch: 0.0,
        faceCenterX: 0.0,
        faceCenterY: 0.0,
        faceAreaRatio: 0.0,
        breathingSignal: 0.0,
        landmarkCoverage: 0.0,
      ));
      _trimBuffer();
      _currentSnapshot = const PassiveLivenessSnapshot.empty();
      _currentStatus = LivenessStatus.waitingForFace;
      _emitStatus();
      _emitProgress();
      return;
    }

    _updateBlinkTracking(face);
    _frameBuffer.add(_deriveFrameData(
      face: face,
      overallMotion: overallMotion,
      noiseVariance: noiseVariance,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    ));
    _trimBuffer();

    if (_currentStatus == LivenessStatus.waitingForFace ||
        _currentStatus == LivenessStatus.initializing ||
        _currentStatus == LivenessStatus.failed) {
      _currentStatus = LivenessStatus.challengeInProgress;
      _emitStatus();
    }

    _refreshPassiveSnapshot();

    if (_currentSnapshot.antiSpoofScore < 0.24 &&
        _frameBuffer.length >= _minFramesForAnalysis) {
      _currentStatus = LivenessStatus.spoofDetected;
      _emitStatus();
      return;
    }

    if (_frameBuffer.length >= _minFramesForAnalysis &&
        _hasAllSignalsPassed(_currentSnapshot) &&
        _currentSnapshot.overallScore >= 0.58 &&
        _currentStatus != LivenessStatus.analyzing &&
        _currentStatus != LivenessStatus.passed) {
      _finalizeLivenessCheck();
    }
  }

  LivenessFrameData _deriveFrameData({
    required Face face,
    required double overallMotion,
    required double noiseVariance,
    required double imageWidth,
    required double imageHeight,
  }) {
    final eyeOpen = ((face.leftEyeOpenProbability ?? 0.5) +
            (face.rightEyeOpenProbability ?? 0.5)) /
        2.0;
    final centerX = imageWidth > 0
        ? (face.boundingBox.center.dx / imageWidth).clamp(0.0, 1.0)
        : 0.5;
    final centerY = imageHeight > 0
        ? (face.boundingBox.center.dy / imageHeight).clamp(0.0, 1.0)
        : 0.5;
    final faceArea = (imageWidth > 0 && imageHeight > 0)
        ? ((face.boundingBox.width * face.boundingBox.height) /
                (imageWidth * imageHeight))
            .clamp(0.0, 1.0)
        : 0.0;
    return LivenessFrameData(
      timestamp: DateTime.now(),
      face: face,
      overallMotion: overallMotion,
      noiseVariance: noiseVariance,
      avgEyeOpen: eyeOpen,
      yaw: face.headEulerAngleY ?? 0.0,
      pitch: face.headEulerAngleX ?? 0.0,
      faceCenterX: centerX,
      faceCenterY: centerY,
      faceAreaRatio: faceArea,
      breathingSignal: _extractBreathingSignal(face),
      landmarkCoverage: _extractLandmarkCoverage(face),
    );
  }

  void _trimBuffer() {
    while (_frameBuffer.length > _maxFramesBuffer) {
      _frameBuffer.removeAt(0);
    }
    while (_depthRiskHistory.length > 24) {
      _depthRiskHistory.removeAt(0);
    }
  }

  void _updateBlinkTracking(Face face) {
    final leftEye = face.leftEyeOpenProbability ?? 0.5;
    final rightEye = face.rightEyeOpenProbability ?? 0.5;
    final avgEye = (leftEye + rightEye) / 2;
    final isEyesClosed = avgEye < _blinkThresholdLow;
    final isEyesOpen = avgEye > _blinkThresholdHigh;
    if (_wasBlinking && isEyesOpen) {
      _blinkCount++;
    }
    if (isEyesClosed) {
      _wasBlinking = true;
    } else if (isEyesOpen) {
      _wasBlinking = false;
    }
  }

  void _refreshPassiveSnapshot() {
    final recent = _frameBuffer.where((f) => f.face != null).toList();
    if (recent.length < 6) {
      _currentSnapshot = const PassiveLivenessSnapshot.empty();
      _completedSignalKeys.clear();
      _emitProgress();
      return;
    }

    final trackingScore = _calculateTrackingScore(recent);
    final poseScore = _calculatePoseScore(recent);
    final eyeActivityScore = _calculateEyeActivityScore(recent);
    final breathingScore = _calculateBreathingScore(recent);
    final textureScore = _calculateTextureScore(recent);
    final landmarkScore = _calculateLandmarkScore(recent);
    final spoofRisk = _calculateSpoofRisk(recent);
    final antiSpoofScore = (1.0 - spoofRisk).clamp(0.0, 1.0);
    final trackingPassed = trackingScore >= 0.42;
    final posePassed = poseScore >= 0.58;
    final eyeActivityPassed = eyeActivityScore >= 0.18;
    final breathingPassed = breathingScore >= 0.12;
    final texturePassed = textureScore >= 0.42;
    final landmarkPassed = landmarkScore >= 0.55;
    final antiSpoofPassed = antiSpoofScore >= 0.45;

    _passedChecks
      ..clear()
      ..addAll(const []);
    _failedChecks
      ..clear()
      ..addAll(const []);
    _completedSignalKeys.clear();

    void evaluateSignal(String key, double value, double threshold) {
      if (value >= threshold) {
        _completedSignalKeys.add(key);
        _passedChecks.add(key);
      } else {
        _failedChecks.add(key);
      }
    }

    evaluateSignal('face_tracking_stable', trackingScore, 0.42);
    evaluateSignal('pose_within_range', poseScore, 0.58);
    evaluateSignal('eye_activity_present', eyeActivityScore, 0.18);
    evaluateSignal('respiration_pattern_present', breathingScore, 0.12);
    evaluateSignal('skin_texture_natural', textureScore, 0.42);
    evaluateSignal('landmark_coverage_ok', landmarkScore, 0.55);
    evaluateSignal('anti_spoof_ok', antiSpoofScore, 0.45);

    final overallScore = ((trackingScore * 0.22) +
            (poseScore * 0.18) +
            (eyeActivityScore * 0.12) +
            (breathingScore * 0.08) +
            (textureScore * 0.14) +
            (landmarkScore * 0.12) +
            (antiSpoofScore * 0.14))
        .clamp(0.0, 1.0);

    _currentSnapshot = PassiveLivenessSnapshot(
      faceDetected: true,
      trackingScore: trackingScore,
      trackingPassed: trackingPassed,
      poseScore: poseScore,
      posePassed: posePassed,
      eyeActivityScore: eyeActivityScore,
      eyeActivityPassed: eyeActivityPassed,
      breathingScore: breathingScore,
      breathingPassed: breathingPassed,
      textureScore: textureScore,
      texturePassed: texturePassed,
      antiSpoofScore: antiSpoofScore,
      antiSpoofPassed: antiSpoofPassed,
      landmarkScore: landmarkScore,
      landmarkPassed: landmarkPassed,
      overallScore: overallScore,
      completedSignals: _completedSignalKeys.length,
      requiredSignals: _requiredSignals,
      totalSignals: _totalSignals,
      guidanceAr: _chooseGuidanceAr(
        trackingScore: trackingScore,
        poseScore: poseScore,
        eyeActivityScore: eyeActivityScore,
        breathingScore: breathingScore,
        textureScore: textureScore,
        antiSpoofScore: antiSpoofScore,
        landmarkScore: landmarkScore,
      ),
      guidanceEn: _chooseGuidanceEn(
        trackingScore: trackingScore,
        poseScore: poseScore,
        eyeActivityScore: eyeActivityScore,
        breathingScore: breathingScore,
        textureScore: textureScore,
        antiSpoofScore: antiSpoofScore,
        landmarkScore: landmarkScore,
      ),
    );
    _emitProgress();
  }

  bool _hasAllSignalsPassed(PassiveLivenessSnapshot snapshot) {
    return snapshot.trackingPassed &&
        snapshot.posePassed &&
        snapshot.eyeActivityPassed &&
        snapshot.breathingPassed &&
        snapshot.texturePassed &&
        snapshot.landmarkPassed &&
        snapshot.antiSpoofPassed;
  }

  double _calculateTrackingScore(List<LivenessFrameData> recent) {
    final centerDx =
        recent.map((f) => (f.faceCenterX - 0.5).abs()).reduce((a, b) => a + b) /
            recent.length;
    final centerDy = recent
            .map((f) => (f.faceCenterY - 0.48).abs())
            .reduce((a, b) => a + b) /
        recent.length;
    final areaAvg = recent.map((f) => f.faceAreaRatio).reduce((a, b) => a + b) /
        recent.length;

    final centerScore =
        (1.0 - ((centerDx / 0.34) * 0.55) - ((centerDy / 0.30) * 0.45))
            .clamp(0.0, 1.0);
    final sizeScore = areaAvg >= 0.05 && areaAvg <= 0.50
        ? 1.0
        : (1.0 - ((areaAvg - 0.20).abs() / 0.24)).clamp(0.0, 1.0);
    return (centerScore * 0.7 + sizeScore * 0.3).clamp(0.0, 1.0);
  }

  double _calculatePoseScore(List<LivenessFrameData> recent) {
    final yawAvg =
        recent.map((f) => f.yaw.abs()).reduce((a, b) => a + b) / recent.length;
    final pitchAvg = recent.map((f) => f.pitch.abs()).reduce((a, b) => a + b) /
        recent.length;
    final yawScore = (1.0 - (yawAvg / _maxYawDegrees)).clamp(0.0, 1.0);
    final pitchScore = (1.0 - (pitchAvg / _maxPitchDegrees)).clamp(0.0, 1.0);
    return ((yawScore * 0.55) + (pitchScore * 0.45)).clamp(0.0, 1.0);
  }

  double _calculateEyeActivityScore(List<LivenessFrameData> recent) {
    final values = recent.map((f) => f.avgEyeOpen).toList();
    final eyeStd = _stdDev(values);
    final avgEye = values.reduce((a, b) => a + b) / values.length;
    final varianceScore = (eyeStd / 0.05).clamp(0.0, 1.0);
    final blinkScore = _blinkCount > 0 ? 1.0 : 0.0;
    final naturalOpenScore =
        avgEye >= 0.30 && avgEye <= 0.95 ? 0.10 : (avgEye > 0.20 ? 0.05 : 0.0);
    return max(max(varianceScore, blinkScore * 0.9), naturalOpenScore)
        .clamp(0.0, 1.0);
  }

  double _calculateBreathingScore(List<LivenessFrameData> recent) {
    final values =
        recent.map((f) => f.breathingSignal).where((v) => v > 0).toList();
    if (values.length < 4) return 0.0;
    final std = _stdDev(values);
    final minV = values.reduce(min);
    final maxV = values.reduce(max);
    final amplitude = (maxV - minV).abs();
    if (std <= 0.0008 && amplitude <= 0.0012) {
      return 0.0;
    }
    final stdScore = (std / 0.006).clamp(0.0, 1.0);
    final ampScore = (amplitude / 0.010).clamp(0.0, 1.0);
    return (0.18 + (stdScore * 0.45) + (ampScore * 0.37)).clamp(0.0, 1.0);
  }

  double _calculateTextureScore(List<LivenessFrameData> recent) {
    final noiseAvg =
        recent.map((f) => f.noiseVariance).reduce((a, b) => a + b) /
            recent.length;
    // معايرة أخف للكاميرات الأمامية الحديثة، خاصة iPhone، بعد قياس
    // الضوضاء من منطقة الوجه نفسها بدل أخذ عينات خام من كامل الإطار.
    final noiseScore = ((noiseAvg - 0.006) / 0.045).clamp(0.0, 1.0);
    if (_depthRiskHistory.isEmpty) return noiseScore;
    final depthScore = 1.0 - averageDepthSpoofRisk;
    return ((depthScore * 0.7) + (noiseScore * 0.3)).clamp(0.0, 1.0);
  }

  double _calculateLandmarkScore(List<LivenessFrameData> recent) {
    return recent.map((f) => f.landmarkCoverage).reduce((a, b) => a + b) /
        recent.length;
  }

  double _calculateSpoofRisk(List<LivenessFrameData> recent) {
    final motionAvg =
        recent.map((f) => f.overallMotion).reduce((a, b) => a + b) /
            recent.length;
    final poseAvg = _calculatePoseScore(recent);
    final eyeScore = _calculateEyeActivityScore(recent);
    final breathing = _calculateBreathingScore(recent);
    final texture = _calculateTextureScore(recent);
    final tracking = _calculateTrackingScore(recent);
    final lowMotionPenalty = motionAvg < 0.003 ? 1.0 : 0.0;
    final blinkPenalty = eyeScore < 0.25 ? 0.8 : 0.0;
    final depthPenalty =
        _depthRiskHistory.isEmpty ? 0.18 : averageDepthSpoofRisk;
    final risk = (lowMotionPenalty * 0.18) +
        ((1.0 - poseAvg) * 0.10) +
        (blinkPenalty * 0.10) +
        ((1.0 - breathing) * 0.06) +
        ((1.0 - texture) * 0.14) +
        ((1.0 - tracking) * 0.08) +
        (depthPenalty * 0.22);
    return risk.clamp(0.0, 1.0);
  }

  String _chooseGuidanceAr({
    required double trackingScore,
    required double poseScore,
    required double eyeActivityScore,
    required double breathingScore,
    required double textureScore,
    required double antiSpoofScore,
    required double landmarkScore,
  }) {
    if (trackingScore < 0.40) {
      return 'حرّك الوجه إلى منتصف الإطار واثبت قليلاً.';
    }
    if (poseScore < 0.50) {
      return 'اجعل الرأس مستقيماً داخل حدود 30 درجة.';
    }
    if (landmarkScore < 0.55) {
      return 'اقترب قليلاً حتى تظهر العينان والأنف والفم بوضوح.';
    }
    if (eyeActivityScore < 0.18) {
      return 'ابق طبيعياً أمام الكاميرا وارمش بشكل عفوي.';
    }
    if (breathingScore < 0.12) {
      return 'ثبّت الهاتف فقط، وسيُحتسب التنفس الطبيعي تلقائياً.';
    }
    if (textureScore < 0.50 || antiSpoofScore < 0.50) {
      return 'تجنب الصور أو الشاشات واجعل الوجه الحقيقي أمام الكاميرا مباشرة.';
    }
    return 'التحليل الحيوي جاهز تقريباً، استمر ثابتاً للحظة.';
  }

  String _chooseGuidanceEn({
    required double trackingScore,
    required double poseScore,
    required double eyeActivityScore,
    required double breathingScore,
    required double textureScore,
    required double antiSpoofScore,
    required double landmarkScore,
  }) {
    if (trackingScore < 0.40) {
      return 'Move your face to the center of the frame and hold steady.';
    }
    if (poseScore < 0.50) {
      return 'Keep your head straight within the 30-degree range.';
    }
    if (landmarkScore < 0.55) {
      return 'Move a little closer so the eyes, nose, and mouth are clear.';
    }
    if (eyeActivityScore < 0.18) {
      return 'Stay natural in front of the camera and blink normally.';
    }
    if (breathingScore < 0.12) {
      return 'Hold the phone steady and natural breathing will be captured automatically.';
    }
    if (textureScore < 0.50 || antiSpoofScore < 0.50) {
      return 'Avoid photos or screens and use a real face directly in front of the camera.';
    }
    return 'Passive biometric analysis is almost ready, hold steady briefly.';
  }

  double _extractBreathingSignal(Face face) {
    try {
      final contours = face.contours;
      final noseBottom = contours[FaceContourType.noseBottom];
      final upperLip = contours[FaceContourType.upperLipTop];
      if (noseBottom == null ||
          upperLip == null ||
          noseBottom.points.isEmpty ||
          upperLip.points.isEmpty) {
        return 0.0;
      }
      final noseCenter = noseBottom.points[noseBottom.points.length ~/ 2];
      final lipCenter = upperLip.points[upperLip.points.length ~/ 2];
      final boxHeight = max(face.boundingBox.height.abs(), 1.0);
      return ((lipCenter.y - noseCenter.y).abs() / boxHeight).clamp(0.0, 1.0);
    } catch (_) {
      return 0.0;
    }
  }

  double _extractLandmarkCoverage(Face face) {
    try {
      final landmarks = face.landmarks;
      int found = 0;
      const expected = 6;
      if (landmarks[FaceLandmarkType.leftEye] != null) found++;
      if (landmarks[FaceLandmarkType.rightEye] != null) found++;
      if (landmarks[FaceLandmarkType.noseBase] != null) found++;
      if (landmarks[FaceLandmarkType.bottomMouth] != null) found++;
      if (landmarks[FaceLandmarkType.leftCheek] != null) found++;
      if (landmarks[FaceLandmarkType.rightCheek] != null) found++;
      return (found / expected).clamp(0.0, 1.0);
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> _finalizeLivenessCheck() async {
    _currentStatus = LivenessStatus.analyzing;
    _emitStatus();
    await Future.delayed(const Duration(milliseconds: 250));
    final recent = _frameBuffer.where((f) => f.face != null).toList();
    final spoofRisk = _calculateSpoofRisk(recent);
    if (spoofRisk >= _spoofRejectThreshold) {
      _currentStatus = LivenessStatus.spoofDetected;
      _emitStatus();
      return;
    }
    if (_hasAllSignalsPassed(_currentSnapshot) &&
        _currentSnapshot.overallScore >= 0.58) {
      _currentStatus = LivenessStatus.passed;
      _emitStatus();
    } else {
      _currentStatus = LivenessStatus.failed;
      _emitStatus();
    }
  }

  LivenessResult getFinalResult() {
    final recent = _frameBuffer.where((f) => f.face != null).toList();
    final spoofRisk = recent.isEmpty ? 1.0 : _calculateSpoofRisk(recent);
    if (_currentStatus == LivenessStatus.passed) {
      return LivenessResult.passed(
        score: _currentSnapshot.overallScore,
        checks: List.unmodifiable(_passedChecks),
      );
    }
    if (_currentStatus == LivenessStatus.spoofDetected) {
      return LivenessResult.failed(
        status: LivenessStatus.spoofDetected,
        message:
            'تم رفض المصادقة لأن النظام اكتشف نمطاً قريباً من صورة أو شاشة أو انتحال.',
        spoofRisk: spoofRisk,
        failedChecks: List.unmodifiable(_failedChecks),
        passedChecks: List.unmodifiable(_passedChecks),
      );
    }
    if (_currentStatus == LivenessStatus.timeout) {
      return LivenessResult.failed(
        status: LivenessStatus.timeout,
        message: 'انتهت مهلة الفحص الحيوي. حاول مرة أخرى.',
        spoofRisk: spoofRisk,
        failedChecks: List.unmodifiable(_failedChecks),
        passedChecks: List.unmodifiable(_passedChecks),
      );
    }
    return LivenessResult.failed(
      status: LivenessStatus.failed,
      message:
          'لم تكتمل جميع مؤشرات التحقق الحيوي المطلوبة بعد. حاول مرة أخرى حتى تجتاز التموضع والوضعية والعينين والتنفس والنسيج والمعالم ومقاومة الانتحال.',
      spoofRisk: spoofRisk,
      failedChecks: List.unmodifiable(_failedChecks),
      passedChecks: List.unmodifiable(_passedChecks),
    );
  }

  double getCurrentProgress() {
    return (_completedSignalKeys.length / _requiredSignals).clamp(0.0, 1.0);
  }

  String getProgressTextAr() =>
      'جاهزية الفحص الحيوي: ${(_currentSnapshot.overallScore * 100).round()}%';
  String getProgressTextEn() =>
      'Passive scan readiness: ${(_currentSnapshot.overallScore * 100).round()}%';

  void dispose() {
    _statusController.close();
    _challengeController.close();
    _progressController.close();
  }

  void recordDepthAnalysisFrame({
    required List<int> pixels,
    required int width,
    required int height,
    Point<double>? faceCenterRel,
    double? faceBoxRelW,
    double? faceBoxRelH,
    Face? detectedFace,
  }) {
    try {
      if (width <= 0 || height <= 0 || pixels.isEmpty) return;
      final Point<double> fc;
      final double fw;
      final double fh;
      if (detectedFace != null) {
        fc = Point<double>(
          (detectedFace.boundingBox.center.dx / width).clamp(0.0, 1.0),
          (detectedFace.boundingBox.center.dy / height).clamp(0.0, 1.0),
        );
        fw = (detectedFace.boundingBox.width / width).clamp(0.0, 1.0);
        fh = (detectedFace.boundingBox.height / height).clamp(0.0, 1.0);
      } else {
        fc = faceCenterRel ?? const Point<double>(0.5, 0.5);
        fw = (faceBoxRelW ?? 0.4).clamp(0.0, 1.0);
        fh = (faceBoxRelH ?? 0.4).clamp(0.0, 1.0);
      }
      final metrics = analyzeDepthAnd3DShape(
        pixels: pixels,
        width: width,
        height: height,
        faceCenterRel: fc,
        faceBoxRelWidth: fw,
        faceBoxRelHeight: fh,
      );
      final risk = computeDepthSpoofRisk(metrics);
      _lastDepthSpoofRisk = risk;
      _depthRiskHistory.add(risk);
      _trimBuffer();
    } catch (_) {}
  }

  static double computeFrameMotion({
    required Face? currentFace,
    required Face? previousFace,
  }) {
    if (currentFace == null || previousFace == null) return 0.0;
    final cb = currentFace.boundingBox;
    final pb = previousFace.boundingBox;
    final dx =
        (cb.center.dx - pb.center.dx).abs() / (pb.width > 0 ? pb.width : 1);
    final dy =
        (cb.center.dy - pb.center.dy).abs() / (pb.height > 0 ? pb.height : 1);
    final dSize = ((cb.width * cb.height) - (pb.width * pb.height)).abs() /
        ((pb.width * pb.height) > 0 ? (pb.width * pb.height) : 1);
    return (dx + dy + dSize).clamp(0.0, 1.0);
  }

  static double computeNoiseVariance(List<int> pixelSamples) {
    if (pixelSamples.isEmpty) return 0.0;
    final mean = pixelSamples.reduce((a, b) => a + b) / pixelSamples.length;
    double sumSq = 0;
    for (final v in pixelSamples) {
      sumSq += (v - mean) * (v - mean);
    }
    return sqrt(sumSq / pixelSamples.length) / 255.0;
  }

  static Map<String, double> analyzeDepthAnd3DShape({
    required List<int> pixels,
    required int width,
    required int height,
    required Point<double> faceCenterRel,
    required double faceBoxRelWidth,
    required double faceBoxRelHeight,
  }) {
    if (pixels.isEmpty || width < 8 || height < 8) {
      return {
        'lightingGradient': 0.5,
        'symmetry': 0.5,
        'edgeSmoothness': 0.5,
        'colorBandFlatness': 0.5,
        'highFreqEnergy': 0.5,
        'skinVariance': 0.5,
      };
    }

    try {
      final fxCenter = faceCenterRel.x.clamp(0.05, 0.95);
      final fyCenter = faceCenterRel.y.clamp(0.05, 0.95);
      final fw = faceBoxRelWidth > 0.1 ? faceBoxRelWidth : 0.4;
      final fh = faceBoxRelHeight > 0.1 ? faceBoxRelHeight : 0.4;

      final xStart = max(1, ((fxCenter - fw * 0.55) * width).floor());
      final xEnd = min(width - 2, ((fxCenter + fw * 0.55) * width).ceil());
      final yStart = max(1, ((fyCenter - fh * 0.55) * height).floor());
      final yEnd = min(height - 2, ((fyCenter + fh * 0.55) * height).ceil());

      double totalLum = 0;
      int lumCount = 0;
      final List<double> luminanceList = [];
      for (int y = yStart; y < yEnd; y += 2) {
        for (int x = xStart; x < xEnd; x += 2) {
          final idx = (y * width + x) * 3;
          if (idx + 2 >= pixels.length) continue;
          final r = pixels[idx];
          final g = pixels[idx + 1];
          final b = pixels[idx + 2];
          final lum = 0.299 * r + 0.587 * g + 0.114 * b;
          totalLum += lum;
          luminanceList.add(lum);
          lumCount++;
        }
      }
      double lightingGradient = 0.5;
      if (lumCount > 20) {
        final avgLum = totalLum / lumCount;
        double varLum = 0;
        for (final l in luminanceList) {
          varLum += (l - avgLum) * (l - avgLum);
        }
        lightingGradient = (sqrt(varLum / lumCount) / 50.0).clamp(0.0, 1.0);
      }

      double leftLum = 0;
      double rightLum = 0;
      int lCnt = 0;
      int rCnt = 0;
      final midX = ((xStart + xEnd) ~/ 2);
      for (int y = yStart; y < yEnd; y += 3) {
        for (int x = xStart; x < midX; x += 3) {
          final idx = (y * width + x) * 3;
          if (idx + 2 >= pixels.length) continue;
          leftLum += 0.299 * pixels[idx] +
              0.587 * pixels[idx + 1] +
              0.114 * pixels[idx + 2];
          lCnt++;
        }
        for (int x = midX; x < xEnd; x += 3) {
          final idx = (y * width + x) * 3;
          if (idx + 2 >= pixels.length) continue;
          rightLum += 0.299 * pixels[idx] +
              0.587 * pixels[idx + 1] +
              0.114 * pixels[idx + 2];
          rCnt++;
        }
      }
      double symmetry = 0.5;
      if (lCnt > 10 && rCnt > 10) {
        final lAvg = leftLum / lCnt;
        final rAvg = rightLum / rCnt;
        final diff = (lAvg - rAvg).abs() / max(max(lAvg, rAvg), 1);
        symmetry = diff < 0.015
            ? 1.0
            : diff < 0.03
                ? 0.7
                : diff < 0.08
                    ? 0.25
                    : 0.0;
      }

      double edgeSum = 0;
      int edgePixels = 0;
      int bandCount = 0;
      int bandSamples = 0;
      for (int y = yStart + 1; y < yEnd - 1; y += 2) {
        for (int x = xStart + 1; x < xEnd - 1; x += 2) {
          final idx = (y * width + x) * 3;
          if (idx + 2 >= pixels.length) continue;
          final gx = pixels[idx + 1];
          final gxm1 = pixels[(y * width + (x - 1)) * 3 + 1];
          final gxp1 = pixels[(y * width + (x + 1)) * 3 + 1];
          final gym1 = pixels[((y - 1) * width + x) * 3 + 1];
          final gyp1 = pixels[((y + 1) * width + x) * 3 + 1];
          final dX = (gxp1 - gxm1).abs();
          final dY = (gyp1 - gym1).abs();
          edgeSum += dX + dY;
          edgePixels++;
          final rowDxL = (gx - gxm1).abs();
          final rowDxR = (gxp1 - gx).abs();
          if (rowDxL < 3 && rowDxR < 3) {
            bandSamples++;
            if (rowDxL <= 1 && rowDxR <= 1) bandCount++;
          }
        }
      }
      final avgEdge = edgePixels > 0 ? edgeSum / edgePixels : 15.0;
      final edgeSmoothness =
          (1.0 - (avgEdge / 30.0).clamp(0.0, 1.0)).clamp(0.0, 1.0);
      final colorBandFlatness =
          bandSamples > 10 ? (bandCount / bandSamples).clamp(0.0, 1.0) : 0.5;

      double hfSum = 0;
      int hfCount = 0;
      for (int y = yStart + 1; y < yEnd - 1; y++) {
        for (int x = xStart + 1; x < xEnd - 1; x++) {
          final idx = (y * width + x) * 3 + 1;
          if (idx >= pixels.length) continue;
          final center = pixels[idx];
          int neighbors = 0;
          int sum = 0;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;
              final ni = ((y + dy) * width + (x + dx)) * 3 + 1;
              if (ni < pixels.length) {
                sum += pixels[ni];
                neighbors++;
              }
            }
          }
          if (neighbors > 0) {
            hfSum += pow(center - (sum / neighbors), 2).toDouble();
            hfCount++;
          }
        }
      }
      final highFreqEnergy =
          hfCount > 0 ? (sqrt(hfSum / hfCount) / 20.0).clamp(0.0, 1.0) : 0.5;

      double skinVarSum = 0;
      int skinVarCount = 0;
      for (int y = yStart + 2; y < yEnd - 2; y += 4) {
        for (int x = xStart + 2; x < xEnd - 2; x += 4) {
          int sumR = 0, sumG = 0, sumB = 0, cnt = 0;
          for (int dy = -2; dy <= 2; dy++) {
            for (int dx = -2; dx <= 2; dx++) {
              final ni = ((y + dy) * width + (x + dx)) * 3;
              if (ni + 2 >= pixels.length) continue;
              sumR += pixels[ni];
              sumG += pixels[ni + 1];
              sumB += pixels[ni + 2];
              cnt++;
            }
          }
          if (cnt == 0) continue;
          final avgR = sumR / cnt;
          final avgG = sumG / cnt;
          final avgB = sumB / cnt;
          double localVar = 0;
          for (int dy = -2; dy <= 2; dy++) {
            for (int dx = -2; dx <= 2; dx++) {
              final ni = ((y + dy) * width + (x + dx)) * 3;
              if (ni + 2 >= pixels.length) continue;
              localVar += ((pixels[ni] - avgR).abs() +
                      (pixels[ni + 1] - avgG).abs() +
                      (pixels[ni + 2] - avgB).abs()) /
                  3.0;
            }
          }
          skinVarSum += localVar / cnt;
          skinVarCount++;
        }
      }
      final skinVariance = skinVarCount > 0
          ? (1.0 - ((skinVarSum / skinVarCount) / 12.0).clamp(0.0, 1.0))
              .clamp(0.0, 1.0)
          : 0.5;

      return {
        'lightingGradient': lightingGradient,
        'symmetry': symmetry,
        'edgeSmoothness': edgeSmoothness,
        'colorBandFlatness': colorBandFlatness,
        'highFreqEnergy': highFreqEnergy,
        'skinVariance': skinVariance,
      };
    } catch (_) {
      return {
        'lightingGradient': 0.5,
        'symmetry': 0.5,
        'edgeSmoothness': 0.5,
        'colorBandFlatness': 0.5,
        'highFreqEnergy': 0.5,
        'skinVariance': 0.5,
      };
    }
  }

  static double computeDepthSpoofRisk(Map<String, double> m) {
    final sym = m['symmetry'] ?? 0.5;
    final esm = m['edgeSmoothness'] ?? 0.5;
    final cbf = m['colorBandFlatness'] ?? 0.5;
    final skv = m['skinVariance'] ?? 0.5;
    final lig = m['lightingGradient'] ?? 0.5;
    final hfe = m['highFreqEnergy'] ?? 0.5;
    return ((sym * 0.22) +
            (esm * 0.18) +
            (cbf * 0.14) +
            (skv * 0.18) +
            ((1.0 - lig) * 0.14) +
            ((1.0 - hfe) * 0.14))
        .clamp(0.0, 1.0);
  }

  double _stdDev(List<double> values) {
    if (values.length < 2) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    double sum = 0;
    for (final v in values) {
      sum += (v - mean) * (v - mean);
    }
    return sqrt(sum / values.length);
  }
}
