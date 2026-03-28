import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationStabilityService {
  static final LocationStabilityService _instance =
      LocationStabilityService._internal();
  factory LocationStabilityService() => _instance;
  LocationStabilityService._internal();

  // دالة تسجيل الأحداث للتطوير
  void _log(String message) {
    if (kDebugMode) {
      print('📍 [LocationStabilityService] $message');
    }
  }

  /// التحقق من ثبات الموقع
  Future<LocationStabilityResult> checkLocationStability({
    required Position currentPosition,
    Duration checkDuration =
        const Duration(seconds: 8), // زيادة من 5 إلى 8 ثواني لتحسين الدقة
    double maxDistanceVariation = 3.0, // تقليل من 5 إلى 3 متر لتحسين الدقة
    int minReadings = 3, // 3 قراءات على الأقل
  }) async {
    try {
      _log('🔍 بدء فحص ثبات الموقع...');
      _log(
          '📍 الموقع الحالي: ${currentPosition.latitude}, ${currentPosition.longitude}');
      _log('⏱️ مدة الفحص: ${checkDuration.inSeconds} ثانية');
      _log('📏 الحد الأقصى للتباين: $maxDistanceVariation متر');

      List<Position> readings = [];
      Timer? timer;
      Completer<LocationStabilityResult> completer = Completer();

      // بدء جمع القراءات
      timer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        try {
          Position newPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(
                seconds: 5), // زيادة من 3 إلى 5 ثواني لتحسين الدقة
          );

          readings.add(newPosition);
          _log(
              '📊 قراءة ${readings.length}: ${newPosition.latitude}, ${newPosition.longitude}');

          // التحقق من عدد القراءات
          if (readings.length >= minReadings) {
            timer.cancel();

            // تحليل ثبات الموقع
            LocationStabilityResult result = _analyzeLocationStability(
              readings,
              maxDistanceVariation,
            );

            _log(
                '📈 نتيجة تحليل الثبات: ${result.isStable ? "ثابت" : "غير ثابت"}');
            _log(
                '📏 أقصى تباين: ${result.maxDistanceVariation.toStringAsFixed(2)} متر');
            _log('📊 عدد القراءات: ${result.totalReadings}');
            _log(
                '🎯 متوسط المسافات: ${result.averageDistance.toStringAsFixed(2)} متر');

            completer.complete(result);
          }
        } catch (e) {
          _log('❌ خطأ في قراءة الموقع: $e');
          readings.add(currentPosition); // استخدام الموقع الحالي كبديل
        }
      });

      // إيقاف الفحص بعد المدة المحددة
      Timer(checkDuration, () {
        if (!completer.isCompleted) {
          timer?.cancel();

          if (readings.length < minReadings) {
            _log(
                '⚠️ عدد القراءات غير كافي: ${readings.length} من $minReadings');
            completer.complete(LocationStabilityResult(
              isStable: false,
              maxDistanceVariation: double.infinity,
              averageDistance: 0,
              totalReadings: readings.length,
              errorMessage:
                  'عدد القراءات غير كافي: ${readings.length} من $minReadings',
              isSuspiciouslyStable: false,
              isFakeLocation: false,
              minVariationPercentage: 50.0,
            ));
          } else {
            LocationStabilityResult result = _analyzeLocationStability(
              readings,
              maxDistanceVariation,
            );
            completer.complete(result);
          }
        }
      });

      return await completer.future;
    } catch (e) {
      _log('❌ خطأ في فحص ثبات الموقع: $e');
      return LocationStabilityResult(
        isStable: false,
        maxDistanceVariation: double.infinity,
        averageDistance: 0,
        totalReadings: 0,
        errorMessage: e.toString(),
        isSuspiciouslyStable: false,
        isFakeLocation: false,
        minVariationPercentage: 50.0,
      );
    }
  }

  /// تحليل ثبات الموقع
  LocationStabilityResult _analyzeLocationStability(
    List<Position> readings,
    double maxDistanceVariation,
  ) {
    if (readings.length < 2) {
      return LocationStabilityResult(
        isStable: false,
        maxDistanceVariation: double.infinity,
        averageDistance: 0,
        totalReadings: readings.length,
        errorMessage: 'عدد القراءات غير كافي للتحليل',
        isSuspiciouslyStable: false,
        isFakeLocation: false,
        minVariationPercentage: 50.0,
      );
    }

    List<double> distances = [];
    double maxDistance = 0;
    double minDistance = double.infinity;

    // حساب المسافات بين جميع القراءات
    for (int i = 0; i < readings.length; i++) {
      for (int j = i + 1; j < readings.length; j++) {
        double distance = Geolocator.distanceBetween(
          readings[i].latitude,
          readings[i].longitude,
          readings[j].latitude,
          readings[j].longitude,
        );
        distances.add(distance);
        if (distance > maxDistance) {
          maxDistance = distance;
        }
        if (distance < minDistance) {
          minDistance = distance;
        }
      }
    }

    // حساب متوسط المسافات
    double averageDistance = distances.isEmpty
        ? 0
        : distances.reduce((a, b) => a + b) / distances.length;

    // تحليل إضافي لكشف المواقع الوهمية
    bool isSuspiciouslyStable =
        _detectSuspiciouslyStableLocation(readings, distances);
    bool isFakeLocation =
        _detectFakeLocation(readings, distances, averageDistance);

    // تحديد ما إذا كان الموقع ثابت ومقبول
    // الموقع مقبول إذا كان:
    // 1. متوسط المسافات <= الحد الأقصى المسموح
    // 2. أو الموقع ثابت بشكل طبيعي (غير مشبوه) وليس موقع وهمي
    // 3. أو الموقع ثابت ولكن مع بعض التباين الطبيعي
    bool isStable = (averageDistance <= maxDistanceVariation) ||
        (!isSuspiciouslyStable && !isFakeLocation && averageDistance > 0) ||
        (!isSuspiciouslyStable && !isFakeLocation && maxDistance > 0.1);

    _log('📊 تحليل المسافات:');
    _log('   • أقصى مسافة: ${maxDistance.toStringAsFixed(2)} متر');
    _log('   • أقل مسافة: ${minDistance.toStringAsFixed(2)} متر');
    _log('   • متوسط المسافات: ${averageDistance.toStringAsFixed(2)} متر');
    _log('   • عدد المسافات المحسوبة: ${distances.length}');
    _log('   • الموقع ثابت: $isStable');
    _log('   • مشبوه في الثبات: $isSuspiciouslyStable');
    _log('   • موقع وهمي محتمل: $isFakeLocation');

    return LocationStabilityResult(
      isStable: isStable,
      maxDistanceVariation: maxDistance,
      averageDistance: averageDistance,
      totalReadings: readings.length,
      errorMessage: null,
      isSuspiciouslyStable: isSuspiciouslyStable,
      isFakeLocation: isFakeLocation,
      minVariationPercentage: 50.0,
    );
  }

  /// كشف المواقع الثابتة بشكل مريب
  bool _detectSuspiciouslyStableLocation(
      List<Position> readings, List<double> distances) {
    if (distances.isEmpty) return false;

    final accuracies = readings.map((r) => r.accuracy).toList();
    final averageAccuracy = accuracies.isEmpty
        ? 0.0
        : accuracies.reduce((a, b) => a + b) / accuracies.length;
    final accuracyVariance =
        accuracies.length >= 2 ? _calculateVariance(accuracies) : 0.0;

    // 1. كشف التطابق التام في الإحداثيات (مشبوه جداً)
    bool hasExactMatches = false;
    int exactMatchCount = 0;
    for (int i = 0; i < readings.length; i++) {
      for (int j = i + 1; j < readings.length; j++) {
        if (readings[i].latitude == readings[j].latitude &&
            readings[i].longitude == readings[j].longitude) {
          exactMatchCount++;
        }
      }
    }

    // الموقع مشبوه فقط إذا كانت جميع القراءات متطابقة تماماً
    hasExactMatches =
        exactMatchCount >= (readings.length * (readings.length - 1) / 2) * 0.9;

    if (hasExactMatches) {
      _log(
          '🚨 كشف تطابق تام في جميع الإحداثيات: $exactMatchCount تطابق من ${readings.length} قراءة');
    }

    // 2. كشف التباين الصفر في جميع القراءات (مشبوه جداً)
    int zeroVariationCount = distances.where((d) => d < 0.001).length;
    bool hasZeroVariation =
        zeroVariationCount >= (distances.length * 0.98); // 98% من المسافات صفر

    // 3. كشف التباين المنتظم جداً (مشبوه)
    bool hasUniformVariation = false;
    if (distances.length >= 5) {
      double variance = _calculateVariance(distances);
      hasUniformVariation = variance < 0.0001; // تباين أقل من 0.1 مم²
    }

    // 4. كشف عدم وجود تباين في الارتفاع والدقة معاً (مشبوه)
    bool hasNoAltitudeVariation = false;
    bool hasNoAccuracyVariation = false;
    if (readings.length >= 5) {
      List<double> altitudes = readings.map((r) => r.altitude).toList();
      List<double> accuracies = readings.map((r) => r.accuracy).toList();
      double altitudeVariance = _calculateVariance(altitudes);
      double accuracyVariance = _calculateVariance(accuracies);
      hasNoAltitudeVariation =
          altitudeVariance < 0.001; // تباين في الارتفاع أقل من 1 مم
      hasNoAccuracyVariation =
          accuracyVariance < 0.0001; // تباين في الدقة أقل من 0.1 مم
    }

    // 5. كشف عدم وجود أي حركة على الإطلاق (مشبوه جداً)
    bool hasNoMovementAtAll = distances.every((d) => d < 0.01); // أقل من 1 سم

    // الموقع مشبوه فقط إذا كان هناك عدة مؤشرات مشبوهة معاً
    bool isSuspicious = (hasExactMatches &&
            hasZeroVariation &&
            averageAccuracy > 0 &&
            averageAccuracy <= 10 &&
            accuracyVariance < 0.5) ||
        (hasUniformVariation &&
            hasNoAltitudeVariation &&
            hasNoAccuracyVariation) ||
        (hasNoMovementAtAll && hasExactMatches);

    if (isSuspicious) {
      _log('🚨 كشف موقع ثابت بشكل مريب:');
      _log('   • تطابق تام في جميع القراءات: $hasExactMatches');
      _log('   • تباين صفر في جميع القراءات: $hasZeroVariation');
      _log('   • تباين منتظم جداً: $hasUniformVariation');
      _log('   • عدم تباين الارتفاع: $hasNoAltitudeVariation');
      _log('   • عدم تباين الدقة: $hasNoAccuracyVariation');
      _log('   • عدم وجود حركة على الإطلاق: $hasNoMovementAtAll');
    }

    return isSuspicious;
  }

  /// كشف المواقع الوهمية المحتملة
  bool _detectFakeLocation(
      List<Position> readings, List<double> distances, double averageDistance) {
    if (readings.isEmpty) return false;

    // 1. كشف الإحداثيات المستديرة (مثل 0.000000)
    bool hasRoundedCoordinates = false;
    for (var reading in readings) {
      String latStr = reading.latitude.toString();
      String lngStr = reading.longitude.toString();

      // كشف الأرقام المستديرة مثل 24.000000 أو 24.500000
      if (latStr.contains('.000000') ||
          latStr.contains('.500000') ||
          lngStr.contains('.000000') ||
          lngStr.contains('.500000')) {
        hasRoundedCoordinates = true;
        _log('🚨 كشف إحداثيات مستديرة: $latStr, $lngStr');
        break;
      }
    }

    // 2. كشف الإحداثيات خارج النطاق الطبيعي
    bool hasInvalidCoordinates = false;
    for (var reading in readings) {
      if (reading.latitude < -90 ||
          reading.latitude > 90 ||
          reading.longitude < -180 ||
          reading.longitude > 180) {
        hasInvalidCoordinates = true;
        _log(
            '🚨 كشف إحداثيات غير صحيحة: ${reading.latitude}, ${reading.longitude}');
        break;
      }
    }

    // 3. كشف الإحداثيات الثابتة في أماكن مشبوهة
    bool hasSuspiciousFixedLocation = false;
    for (var reading in readings) {
      // كشف الإحداثيات في وسط المحيط (0,0) أو أماكن مشبوهة أخرى
      if ((reading.latitude.abs() < 0.001 && reading.longitude.abs() < 0.001) ||
          (reading.latitude == 0.0 && reading.longitude == 0.0)) {
        hasSuspiciousFixedLocation = true;
        _log('🚨 كشف موقع مشبوه: ${reading.latitude}, ${reading.longitude}');
        break;
      }
    }

    // 4. كشف عدم وجود تباين في الوقت (timestamps)
    bool hasNoTimeVariation = false;
    if (readings.length >= 3) {
      List<DateTime> timestamps = readings.map((r) => r.timestamp).toList();
      timestamps.sort();
      Duration totalDuration = timestamps.last.difference(timestamps.first);
      hasNoTimeVariation =
          totalDuration.inSeconds < 2; // أقل من ثانيتين بين القراءات
    }

    bool isFake = hasRoundedCoordinates ||
        hasInvalidCoordinates ||
        hasSuspiciousFixedLocation ||
        hasNoTimeVariation;

    if (isFake) {
      _log('🚨 كشف موقع وهمي محتمل:');
      _log('   • إحداثيات مستديرة: $hasRoundedCoordinates');
      _log('   • إحداثيات غير صحيحة: $hasInvalidCoordinates');
      _log('   • موقع مشبوه: $hasSuspiciousFixedLocation');
      _log('   • عدم تباين الوقت: $hasNoTimeVariation');
    }

    return isFake;
  }

  /// حساب التباين (variance) لمجموعة من القيم
  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;

    double mean = values.reduce((a, b) => a + b) / values.length;
    double sumSquaredDiff =
        values.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b);

    return sumSquaredDiff / values.length;
  }

  /// التحقق السريع من ثبات الموقع (قراءتين فقط)
  Future<bool> quickLocationStabilityCheck({
    required Position currentPosition,
    double maxDistanceVariation = 5.0,
  }) async {
    try {
      _log('⚡ فحص سريع لثبات الموقع...');

      // قراءة ثانية
      Position secondReading = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      // حساب المسافة بين القراءتين
      double distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        secondReading.latitude,
        secondReading.longitude,
      );

      bool isStable = distance <= maxDistanceVariation;

      _log('📏 المسافة بين القراءتين: ${distance.toStringAsFixed(2)} متر');
      _log('🎯 الموقع ثابت: $isStable');

      return isStable;
    } catch (e) {
      _log('❌ خطأ في الفحص السريع: $e');
      return false;
    }
  }

  /// الحصول على رسالة وصفية لثبات الموقع
  String getStabilityDescription(LocationStabilityResult result) {
    if (result.errorMessage != null) {
      return 'خطأ في فحص ثبات الموقع: ${result.errorMessage}';
    }

    // كشف المواقع الوهمية أولاً
    if (result.isFakeLocation == true) {
      return 'موقع وهمي محتمل - تم رفض العملية';
    }

    if (result.isSuspiciouslyStable == true) {
      return 'الموقع ثابت بشكل مريب - مشبوه في التلاعب';
    }

    if (result.isStable) {
      if (result.maxDistanceVariation <= 1.0) {
        return 'الموقع ثابت جداً (تباين: ${result.maxDistanceVariation.toStringAsFixed(2)} متر)';
      } else if (result.maxDistanceVariation <= 3.0) {
        return 'الموقع ثابت (تباين: ${result.maxDistanceVariation.toStringAsFixed(2)} متر)';
      } else {
        return 'الموقع مقبول (تباين: ${result.maxDistanceVariation.toStringAsFixed(2)} متر)';
      }
    } else {
      if (result.maxDistanceVariation > 50.0) {
        return 'الموقع متغير بشكل كبير (تباين: ${result.maxDistanceVariation.toStringAsFixed(2)} متر) - مشبوه';
      } else if (result.maxDistanceVariation > 20.0) {
        return 'الموقع متغير (تباين: ${result.maxDistanceVariation.toStringAsFixed(2)} متر)';
      } else {
        return 'الموقع غير ثابت (تباين: ${result.maxDistanceVariation.toStringAsFixed(2)} متر)';
      }
    }
  }

  /// الحصول على لون مناسب لثبات الموقع
  int getStabilityColor(LocationStabilityResult result) {
    if (result.errorMessage != null) return 0xFFE53E3E; // أحمر للخطأ

    // المواقع الوهمية والمشبوهة
    if (result.isFakeLocation == true) return 0xFFE53E3E; // أحمر للموقع الوهمي
    if (result.isSuspiciouslyStable == true) {
      return 0xFFDD6B20; // برتقالي للمشبوه
    }

    if (result.isStable) {
      if (result.maxDistanceVariation <= 1.0) {
        return 0xFF38A169; // أخضر داكن للثابت جداً
      }
      if (result.maxDistanceVariation <= 3.0) return 0xFF48BB78; // أخضر للثابت
      return 0xFF68D391; // أخضر فاتح للمقبول
    } else {
      if (result.maxDistanceVariation > 50.0) return 0xFFE53E3E; // أحمر للمشبوه
      if (result.maxDistanceVariation > 20.0) {
        return 0xFFDD6B20; // برتقالي للمتغير
      }
      return 0xFFF6AD55; // برتقالي فاتح للغير ثابت
    }
  }

  /// الحصول على أيقونة مناسبة لثبات الموقع
  String getStabilityIcon(LocationStabilityResult result) {
    if (result.errorMessage != null) return '❌';

    // المواقع الوهمية والمشبوهة
    if (result.isFakeLocation == true) return '🚫';
    if (result.isSuspiciouslyStable == true) return '⚠️';

    if (result.isStable) {
      if (result.maxDistanceVariation <= 1.0) return '🎯';
      if (result.maxDistanceVariation <= 3.0) return '📍';
      return '📌';
    } else {
      if (result.maxDistanceVariation > 50.0) return '🚨';
      if (result.maxDistanceVariation > 20.0) return '⚠️';
      return '🔸';
    }
  }

  /// فحص ثبات الموقع مع 5 تحديثات متتالية
  Future<LocationStabilityResult> checkLocationStabilityWithUpdates({
    required Position initialPosition,
    Duration updateInterval = const Duration(seconds: 2),
    int requiredUpdates = 5,
    double minVariationPercentage = 1.0, // 1% كحد أدنى للفروقات
  }) async {
    try {
      _log('🔍 بدء فحص ثبات الموقع مع $requiredUpdates تحديثات...');
      _log(
          '📍 الموقع الأولي: ${initialPosition.latitude}, ${initialPosition.longitude}');
      _log('⏱️ الفاصل الزمني: ${updateInterval.inSeconds} ثانية');
      _log('📊 الحد الأدنى للفروقات: $minVariationPercentage%');

      List<Position> readings = [initialPosition];
      List<double> variations = [];
      Timer? timer;
      Completer<LocationStabilityResult> completer = Completer();
      bool isCompleting = false;

      // بدء جمع القراءات
      timer = Timer.periodic(updateInterval, (timer) async {
        if (completer.isCompleted || isCompleting) return;
        try {
          Position? newPosition;
          try {
            newPosition = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(
                seconds: 12),
            );
          } catch (_) {
            newPosition = await Geolocator.getLastKnownPosition();
          }

          if (newPosition == null) {
            _log('❌ خطأ في قراءة الموقع: لا توجد قراءة جديدة');
            return;
          }

          readings.add(newPosition);

          // حساب الفرق بين القراءة الحالية والسابقة
          if (readings.length > 1) {
            double distance = Geolocator.distanceBetween(
              readings[readings.length - 2].latitude,
              readings[readings.length - 2].longitude,
              newPosition.latitude,
              newPosition.longitude,
            );

            // حساب نسبة الفرق بالنسبة للدقة
            double accuracy = readings[readings.length - 2].accuracy;
            double variationPercentage =
                accuracy > 0 ? (distance / accuracy) * 100 : 0;
            variations.add(variationPercentage);

            _log(
                '📊 تحديث ${readings.length}: ${newPosition.latitude}, ${newPosition.longitude}');
            _log('📏 المسافة: ${distance.toStringAsFixed(2)} متر');
            _log('📊 نسبة الفرق: ${variationPercentage.toStringAsFixed(1)}%');
          }

          // التحقق من عدد القراءات
          if (readings.length >= requiredUpdates) {
            isCompleting = true;
            timer.cancel();

            // تحليل ثبات الموقع
            LocationStabilityResult result =
                _analyzeLocationStabilityWithVariations(
              readings,
              variations,
              minVariationPercentage,
            );

            _log(
                '📈 نتيجة تحليل الثبات: ${result.isStable ? "ثابت" : "غير ثابت"}');
            _log('📊 عدد القراءات: ${result.totalReadings}');
            _log(
                '📊 متوسط الفروقات: ${result.averageVariationPercentage?.toStringAsFixed(1)}%');

            completer.complete(result);
          }
        } catch (e) {
          _log('❌ خطأ في قراءة الموقع: $e');
        }
      });

      // إيقاف الفحص بعد مدة معقولة
      Timer(
          Duration(
              seconds: updateInterval.inSeconds * requiredUpdates +
                  8), // زيادة من +5 إلى +8 لتحسين الدقة
          () {
        if (!completer.isCompleted) {
          isCompleting = true;
          timer?.cancel();

          if (readings.length < requiredUpdates) {
            _log(
                '⚠️ عدد القراءات غير كافي: ${readings.length} من $requiredUpdates');
            completer.complete(LocationStabilityResult(
              isStable: false,
              maxDistanceVariation: double.infinity,
              averageDistance: 0,
              totalReadings: readings.length,
              errorMessage:
                  'عدد القراءات غير كافي: ${readings.length} من $requiredUpdates',
              isSuspiciouslyStable: false,
              isFakeLocation: false,
              averageVariationPercentage: 0,
              minVariationPercentage: minVariationPercentage,
            ));
          } else {
            LocationStabilityResult result =
                _analyzeLocationStabilityWithVariations(
              readings,
              variations,
              minVariationPercentage,
            );
            completer.complete(result);
          }
        }
      });

      return await completer.future;
    } catch (e) {
      _log('❌ خطأ في فحص ثبات الموقع: $e');
      return LocationStabilityResult(
        isStable: false,
        maxDistanceVariation: double.infinity,
        averageDistance: 0,
        totalReadings: 0,
        errorMessage: e.toString(),
        isSuspiciouslyStable: false,
        isFakeLocation: false,
        averageVariationPercentage: 0,
        minVariationPercentage: minVariationPercentage,
      );
    }
  }

  /// تحليل ثبات الموقع مع الفروقات
  LocationStabilityResult _analyzeLocationStabilityWithVariations(
    List<Position> readings,
    List<double> variations,
    double minVariationPercentage,
  ) {
    if (readings.length < 2) {
      return LocationStabilityResult(
        isStable: false,
        maxDistanceVariation: double.infinity,
        averageDistance: 0,
        totalReadings: readings.length,
        errorMessage: 'عدد القراءات غير كافي للتحليل',
        isSuspiciouslyStable: false,
        isFakeLocation: false,
        averageVariationPercentage: 0,
        minVariationPercentage: minVariationPercentage,
      );
    }

    // حساب المسافات بين جميع القراءات
    List<double> distances = [];
    double maxDistance = 0;

    for (int i = 0; i < readings.length; i++) {
      for (int j = i + 1; j < readings.length; j++) {
        double distance = Geolocator.distanceBetween(
          readings[i].latitude,
          readings[i].longitude,
          readings[j].latitude,
          readings[j].longitude,
        );
        distances.add(distance);
        if (distance > maxDistance) {
          maxDistance = distance;
        }
      }
    }

    // حساب متوسط المسافات
    double averageDistance = distances.isEmpty
        ? 0
        : distances.reduce((a, b) => a + b) / distances.length;

    // حساب متوسط الفروقات
    double averageVariation = variations.isEmpty
        ? 0
        : variations.reduce((a, b) => a + b) / variations.length;

    // تحليل إضافي لكشف المواقع الوهمية
    bool isSuspiciouslyStable =
        _detectSuspiciouslyStableLocation(readings, distances);
    bool isFakeLocation =
        _detectFakeLocation(readings, distances, averageDistance);

    final accuracies = readings.map((r) => r.accuracy).toList();
    final averageAccuracy = accuracies.isEmpty
        ? 0.0
        : accuracies.reduce((a, b) => a + b) / accuracies.length;
    if (averageAccuracy >= 25) {
      isSuspiciouslyStable = false;
      isFakeLocation = false;
    }

    // تحديد ما إذا كان الموقع ثابت ومقبول
    // الموقع مقبول إذا كان:
    // 1. متوسط الفروقات >= الحد الأدنى المطلوب
    // 2. أو الموقع ثابت بشكل طبيعي (غير مشبوه) وليس موقع وهمي
    // 3. أو الموقع ثابت ولكن مع بعض التباين الطبيعي
    bool isStable = (averageVariation >= minVariationPercentage) ||
        (!isSuspiciouslyStable && !isFakeLocation && averageDistance > 0) ||
        (!isSuspiciouslyStable && !isFakeLocation && maxDistance > 0.1);

    _log('📊 تحليل الفروقات:');
    _log('   • متوسط الفروقات: ${averageVariation.toStringAsFixed(1)}%');
    _log('   • الحد الأدنى المطلوب: $minVariationPercentage%');
    _log('   • أقصى مسافة: ${maxDistance.toStringAsFixed(2)} متر');
    _log('   • متوسط المسافات: ${averageDistance.toStringAsFixed(2)} متر');
    _log('   • عدد القراءات: ${readings.length}');
    _log('   • الموقع ثابت: $isStable');
    _log('   • مشبوه في الثبات: $isSuspiciouslyStable');
    _log('   • موقع وهمي محتمل: $isFakeLocation');

    return LocationStabilityResult(
      isStable: isStable,
      maxDistanceVariation: maxDistance,
      averageDistance: averageDistance,
      totalReadings: readings.length,
      errorMessage: null,
      isSuspiciouslyStable: isSuspiciouslyStable,
      isFakeLocation: isFakeLocation,
      averageVariationPercentage: averageVariation,
      minVariationPercentage: minVariationPercentage,
    );
  }
}

/// نموذج نتيجة تحليل ثبات الموقع
class LocationStabilityResult {
  final bool isStable;
  final double maxDistanceVariation;
  final double averageDistance;
  final int totalReadings;
  final String? errorMessage;
  final bool isSuspiciouslyStable;
  final bool isFakeLocation;
  final double? averageVariationPercentage;
  final double minVariationPercentage;

  LocationStabilityResult({
    required this.isStable,
    required this.maxDistanceVariation,
    required this.averageDistance,
    required this.totalReadings,
    this.errorMessage,
    required this.isSuspiciouslyStable,
    required this.isFakeLocation,
    this.averageVariationPercentage,
    required this.minVariationPercentage,
  });

  @override
  String toString() {
    return 'LocationStabilityResult(isStable: $isStable, maxVariation: ${maxDistanceVariation.toStringAsFixed(2)}m, avgDistance: ${averageDistance.toStringAsFixed(2)}m, readings: $totalReadings, error: $errorMessage)';
  }
}
