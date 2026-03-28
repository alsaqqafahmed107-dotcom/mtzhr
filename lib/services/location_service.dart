import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/location.dart';

class LocationService {
  // دالة تسجيل الأحداث للتطوير
  static void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  // جلب جميع المواقع المتاحة
  static Future<List<LocationModel>> getLocations(int clientId) async {
    try {
      final url = '${ApiConfig.baseUrl}/api/$clientId/locations';
      _log('🔗 جلب المواقع من: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final locationResponse = LocationListResponse.fromJson(data);

        if (locationResponse.success) {
          _log('✅ تم جلب ${locationResponse.locations.length} موقع بنجاح');
          return locationResponse.locations;
        } else {
          throw Exception(locationResponse.message);
        }
      } else {
        throw Exception('فشل في جلب المواقع: ${response.statusCode}');
      }
    } catch (e) {
      _log('❌ خطأ في جلب المواقع: $e');
      throw Exception('خطأ في الاتصال: $e');
    }
  }

  // حساب المسافة بين نقطتين باستخدام صيغة هافرساين
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // نصف قطر الأرض بالمتر

    // تحويل الدرجات إلى راديان
    final double lat1Rad = lat1 * pi / 180;
    final double lon1Rad = lon1 * pi / 180;
    final double lat2Rad = lat2 * pi / 180;
    final double lon2Rad = lon2 * pi / 180;

    // الفروق في الإحداثيات
    final double deltaLat = lat2Rad - lat1Rad;
    final double deltaLon = lon2Rad - lon1Rad;

    // صيغة هافرساين
    final double a = sin(deltaLat / 2) * sin(deltaLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    // المسافة بالمتر
    return earthRadius * c;
  }

  // التحقق من أن الموظف داخل نطاق أي موقع
  static LocationValidationResult validateEmployeeLocation(
      double employeeLat, double employeeLon, List<LocationModel> locations) {
    if (locations.isEmpty) {
      return LocationValidationResult(
        isValid: false,
        message: 'لا توجد مواقع مسجلة للتحقق من الموقع',
        nearestLocation: null,
        distance: null,
      );
    }

    LocationModel? nearestLocation;
    double? minDistance;
    const double toleranceMeters = 30; // 30 متر إضافية للتسامح

    for (final location in locations) {
      if (location.longitude == null || location.latitude == null) {
        continue; // تخطي المواقع بدون إحداثيات
      }

      final distance = calculateDistance(
        employeeLat,
        employeeLon,
        location.latitude!,
        location.longitude!,
      );

      // التحقق من أن المسافة أقل من نصف قطر الموقع + التسامح
      final allowedRadius = (location.radiusMeters ?? 100) + toleranceMeters;

      if (distance <= allowedRadius) {
        return LocationValidationResult(
          isValid: true,
          message: 'الموقع صحيح - داخل نطاق ${location.locationName}',
          nearestLocation: location,
          distance: distance,
        );
      }

      // تتبع أقرب موقع
      if (minDistance == null || distance < minDistance) {
        minDistance = distance;
        nearestLocation = location;
      }
    }

    // إذا لم يكن داخل أي موقع
    return LocationValidationResult(
      isValid: false,
      message:
          'الموقع خارج النطاق المسموح. أقرب موقع: ${nearestLocation?.locationName} (${minDistance?.toStringAsFixed(1)} متر)',
      nearestLocation: nearestLocation,
      distance: minDistance,
    );
  }

  // التحقق من الموقع مع جلب المواقع تلقائياً
  static Future<LocationValidationResult> validateLocationWithAPI(
      double employeeLat, double employeeLon, int clientId) async {
    try {
      final locations = await getLocations(clientId);
      return validateEmployeeLocation(employeeLat, employeeLon, locations);
    } catch (e) {
      return LocationValidationResult(
        isValid: false,
        message: 'خطأ في التحقق من الموقع: $e',
        nearestLocation: null,
        distance: null,
      );
    }
  }
}

class LocationValidationResult {
  final bool isValid;
  final String message;
  final LocationModel? nearestLocation;
  final double? distance;

  LocationValidationResult({
    required this.isValid,
    required this.message,
    this.nearestLocation,
    this.distance,
  });

  @override
  String toString() {
    return 'LocationValidationResult(isValid: $isValid, message: $message, distance: $distance)';
  }
}
