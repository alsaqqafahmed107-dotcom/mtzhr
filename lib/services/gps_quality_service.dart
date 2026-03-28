import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GpsQualityService {
  static final GpsQualityService _instance = GpsQualityService._internal();
  factory GpsQualityService() => _instance;
  GpsQualityService._internal();

  // دالة تسجيل الأحداث للتطوير
  void _log(String message) {
    if (kDebugMode) {
      print('🛰️ [GpsQualityService] $message');
    }
  }

  /// التحقق من جودة إشارة GPS
  Future<GpsQualityResult> checkGpsQuality() async {
    try {
      _log('🔍 بدء فحص جودة إشارة GPS...');

      // الحصول على الموقع مع معلومات مفصلة
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 15),
      );

      _log(
          '📍 تم الحصول على الموقع: ${position.latitude}, ${position.longitude}');
      _log('📊 دقة الموقع: ${position.accuracy} متر');
      _log('⏰ وقت التحديث: ${position.timestamp}');

      // تحليل جودة الإشارة
      GpsQualityResult result = _analyzeGpsQuality(position);

      _log('📈 نتيجة تحليل الجودة: ${result.isGoodQuality ? "جيدة" : "ضعيفة"}');
      _log('🛰️ عدد الأقمار الصناعية المقدر: ${result.estimatedSatellites}');
      _log('🎯 مستوى الثقة: ${result.confidenceLevel}%');

      return result;
    } catch (e) {
      _log('❌ خطأ في فحص جودة GPS: $e');
      return GpsQualityResult(
        isGoodQuality: false,
        estimatedSatellites: 0,
        accuracy: 0,
        confidenceLevel: 0,
        errorMessage: e.toString(),
      );
    }
  }

  /// تحليل جودة إشارة GPS بناءً على دقة الموقع
  GpsQualityResult _analyzeGpsQuality(Position position) {
    double accuracy = position.accuracy;

    // تقدير عدد الأقمار الصناعية بناءً على الدقة
    int estimatedSatellites = _estimateSatellitesFromAccuracy(accuracy);

    // حساب مستوى الثقة
    double confidenceLevel =
        _calculateConfidenceLevel(accuracy, estimatedSatellites);

    // تحديد ما إذا كانت الجودة جيدة
    bool isGoodQuality =
        accuracy <= 20.0 && estimatedSatellites >= 4 && confidenceLevel >= 60.0;

    return GpsQualityResult(
      isGoodQuality: isGoodQuality,
      estimatedSatellites: estimatedSatellites,
      accuracy: accuracy,
      confidenceLevel: confidenceLevel,
      errorMessage: null,
    );
  }

  /// تقدير عدد الأقمار الصناعية بناءً على دقة الموقع
  int _estimateSatellitesFromAccuracy(double accuracy) {
    if (accuracy <= 3.0) return 8; // دقة عالية جداً - 8+ أقمار
    if (accuracy <= 5.0) return 7; // دقة عالية - 7 أقمار
    if (accuracy <= 8.0) return 6; // دقة جيدة - 6 أقمار
    if (accuracy <= 12.0) return 5; // دقة متوسطة - 5 أقمار
    if (accuracy <= 20.0) return 4; // دقة مقبولة - 4 أقمار
    if (accuracy <= 30.0) return 3; // دقة ضعيفة - 3 أقمار
    if (accuracy <= 50.0) return 2; // دقة ضعيفة جداً - 2 قمر
    return 1; // دقة سيئة - قمر واحد أو أقل
  }

  /// حساب مستوى الثقة بناءً على الدقة وعدد الأقمار
  double _calculateConfidenceLevel(double accuracy, int satellites) {
    // حساب الثقة بناءً على الدقة (40% من النتيجة)
    double accuracyScore = 0.0;
    if (accuracy <= 3.0) {
      accuracyScore = 40.0;
    } else if (accuracy <= 5.0)
      accuracyScore = 35.0;
    else if (accuracy <= 8.0)
      accuracyScore = 30.0;
    else if (accuracy <= 12.0)
      accuracyScore = 25.0;
    else if (accuracy <= 20.0)
      accuracyScore = 20.0;
    else if (accuracy <= 30.0)
      accuracyScore = 15.0;
    else if (accuracy <= 50.0)
      accuracyScore = 10.0;
    else
      accuracyScore = 5.0;

    // حساب الثقة بناءً على عدد الأقمار (60% من النتيجة)
    double satelliteScore = 0.0;
    if (satellites >= 8) {
      satelliteScore = 60.0;
    } else if (satellites >= 7)
      satelliteScore = 55.0;
    else if (satellites >= 6)
      satelliteScore = 50.0;
    else if (satellites >= 5)
      satelliteScore = 45.0;
    else if (satellites >= 4)
      satelliteScore = 40.0;
    else if (satellites >= 3)
      satelliteScore = 30.0;
    else if (satellites >= 2)
      satelliteScore = 20.0;
    else
      satelliteScore = 10.0;

    return accuracyScore + satelliteScore;
  }

  /// التحقق من أن عدد الأقمار كافي لتسجيل الحضور
  bool isSatelliteCountSufficient(int satelliteCount) {
    return satelliteCount >= 4;
  }

  /// الحصول على رسالة وصفية لجودة GPS
  String getGpsQualityDescription(GpsQualityResult result) {
    if (result.errorMessage != null) {
      return 'خطأ في الحصول على إشارة GPS: ${result.errorMessage}';
    }

    if (result.isGoodQuality) {
      if (result.estimatedSatellites >= 8) {
        return 'إشارة GPS ممتازة (${result.estimatedSatellites} أقمار صناعية)';
      } else if (result.estimatedSatellites >= 6) {
        return 'إشارة GPS جيدة جداً (${result.estimatedSatellites} أقمار صناعية)';
      } else {
        return 'إشارة GPS جيدة (${result.estimatedSatellites} أقمار صناعية)';
      }
    } else {
      if (result.estimatedSatellites < 4) {
        return 'إشارة GPS ضعيفة (${result.estimatedSatellites} أقمار صناعية فقط - مطلوب 4+ أقمار)';
      } else if (result.accuracy > 20.0) {
        return 'دقة GPS منخفضة (${result.accuracy.toStringAsFixed(1)} متر)';
      } else {
        if (result.confidenceLevel < 60.0) {
          return 'إشارة GPS غير كافية (مستوى الثقة: ${result.confidenceLevel.toStringAsFixed(1)}%. مطلوب 60% على الأقل)';
        }
      }
    }

    return 'إشارة GPS جيدة';
  }

  /// الحصول على لون مناسب لحالة GPS
  int getGpsQualityColor(GpsQualityResult result) {
    if (result.errorMessage != null) return 0xFFE53E3E; // أحمر للخطأ

    if (result.isGoodQuality) {
      if (result.estimatedSatellites >= 8) {
        return 0xFF38A169; // أخضر داكن للممتاز
      }
      if (result.estimatedSatellites >= 6) return 0xFF48BB78; // أخضر للجيد جداً
      return 0xFF68D391; // أخضر فاتح للجيد
    } else {
      if (result.estimatedSatellites < 4) return 0xFFE53E3E; // أحمر للضعيف جداً
      if (result.accuracy > 20.0) return 0xFFDD6B20; // برتقالي للدقة المنخفضة
      return 0xFFF6AD55; // برتقالي فاتح للغير كافي
    }
  }

  /// الحصول على أيقونة مناسبة لحالة GPS
  String getGpsQualityIcon(GpsQualityResult result) {
    if (result.errorMessage != null) return '❌';

    if (result.isGoodQuality) {
      if (result.estimatedSatellites >= 8) return '🛰️';
      if (result.estimatedSatellites >= 6) return '📡';
      return '📶';
    } else {
      if (result.estimatedSatellites < 4) return '📴';
      if (result.accuracy > 20.0) return '⚠️';
      return '🔸';
    }
  }
}

/// نموذج نتيجة تحليل جودة GPS
class GpsQualityResult {
  final bool isGoodQuality;
  final int estimatedSatellites;
  final double accuracy;
  final double confidenceLevel;
  final String? errorMessage;

  GpsQualityResult({
    required this.isGoodQuality,
    required this.estimatedSatellites,
    required this.accuracy,
    required this.confidenceLevel,
    this.errorMessage,
  });

  @override
  String toString() {
    return 'GpsQualityResult(isGoodQuality: $isGoodQuality, satellites: $estimatedSatellites, accuracy: $accuracy, confidence: $confidenceLevel, error: $errorMessage)';
  }
}
