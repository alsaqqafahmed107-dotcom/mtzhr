import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class BiometricService {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  // دالة تسجيل الأحداث للتطوير
  static void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  // التحقق من توفر البصمة
  static Future<bool> canCheckBiometrics() async {
    if (kIsWeb) return false;
    try {
      _log('🔍 BiometricService: التحقق من توفر البصمة...');

      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      _log('🔍 BiometricService: canCheckBiometrics: $canCheckBiometrics');

      final isDeviceSupported = await _localAuth.isDeviceSupported();
      _log('🔍 BiometricService: isDeviceSupported: $isDeviceSupported');

      final result = canCheckBiometrics && isDeviceSupported;
      _log('🔍 BiometricService: النتيجة النهائية: $result');

      return result;
    } catch (e) {
      _log('💥 BiometricService: خطأ في التحقق من توفر البصمة: $e');
      return false;
    }
  }

  // الحصول على أنواع البصمة المتوفرة
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return [];
    try {
      _log('🔍 BiometricService: جلب أنواع البصمة المتوفرة...');
      final biometrics = await _localAuth.getAvailableBiometrics();
      _log('🔍 BiometricService: أنواع البصمة المتوفرة: $biometrics');
      return biometrics;
    } catch (e) {
      _log('💥 BiometricService: خطأ في جلب أنواع البصمة: $e');
      return [];
    }
  }

  // التحقق من البصمة للحضور
  static Future<bool> authenticateForAttendance({
    required bool isCheckIn,
    String? employeeName,
  }) async {
    if (kIsWeb) return false;
    try {
      final biometricsAvailable = await canCheckBiometrics();
      if (!biometricsAvailable) {
        _log('❌ BiometricService: البصمة غير متوفرة في هذا الجهاز');
        return false;
      }

      final availableBiometrics = await getAvailableBiometrics();
      if (availableBiometrics.isEmpty) {
        _log('❌ BiometricService: لا توجد أنواع بصمة متوفرة');
        return false;
      }

      final operation = isCheckIn ? 'الحضور' : 'الانصراف';
      final employee = employeeName ?? 'الموظف';

      final result = await _localAuth
          .authenticate(
            localizedReason:
                'يرجى التحقق من البصمة لتسجيل $operation - $employee',
            options: const AuthenticationOptions(
              biometricOnly: true,
              stickyAuth: true,
            ),
          )
          .timeout(const Duration(
              seconds: 15)); // زيادة من 10 إلى 15 ثانية لتحسين الدقة

      return result;
    } catch (e) {
      _log('💥 BiometricService: خطأ في التحقق من البصمة: $e');
      return false;
    }
  }

  // تسجيل البصمة مع خيارات بديلة
  static Future<String?> registerFingerprint(String reason) async {
    if (kIsWeb) return null;
    try {
      _log('🔐 BiometricService: بدء تسجيل البصمة...');

      final biometricsAvailable = await canCheckBiometrics();
      _log('🔐 BiometricService: توفر البصمة: $biometricsAvailable');

      if (!biometricsAvailable) {
        _log('❌ BiometricService: البصمة غير متوفرة في هذا الجهاز');
        return null;
      }

      final availableBiometrics = await getAvailableBiometrics();
      _log('🔐 BiometricService: أنواع البصمة المتوفرة: $availableBiometrics');

      if (!availableBiometrics.contains(BiometricType.fingerprint)) {
        _log('❌ BiometricService: البصمة غير متوفرة');
        return null;
      }

      _log('🔐 BiometricService: بدء عملية التحقق من البصمة...');
      _log('🔐 BiometricService: السبب: $reason');

      // محاولة التحقق من البصمة
      final result = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      _log('🔐 BiometricService: نتيجة التحقق من البصمة: $result');

      if (result) {
        _log('✅ BiometricService: تم التحقق من البصمة بنجاح، إنشاء بيانات...');

        final biometricData = {
          'type': 'fingerprint',
          'timestamp': DateTime.now().toIso8601String(),
          'device': 'Flutter Mobile App',
          'registered': true,
          'reason': reason,
        };

        final encodedData =
            base64Encode(utf8.encode(json.encode(biometricData)));
        _log(
            '✅ BiometricService: تم إنشاء بيانات البصمة، الطول: ${encodedData.length}');

        return encodedData;
      } else {
        _log('❌ BiometricService: فشل في التحقق من البصمة');
        return null;
      }
    } catch (e) {
      _log('💥 BiometricService: خطأ في تسجيل البصمة: $e');
      return null;
    }
  }

  // تسجيل الوجه مع خيارات بديلة
  static Future<String?> registerFace(String reason) async {
    if (kIsWeb) return null;
    try {
      _log('👤 BiometricService: بدء تسجيل الوجه...');

      final biometricsAvailable = await canCheckBiometrics();
      _log('👤 BiometricService: توفر البصمة: $biometricsAvailable');

      if (!biometricsAvailable) {
        _log('❌ BiometricService: التعرف على الوجه غير متوفر في هذا الجهاز');
        return null;
      }

      final availableBiometrics = await getAvailableBiometrics();
      _log('👤 BiometricService: أنواع البصمة المتوفرة: $availableBiometrics');

      if (!availableBiometrics.contains(BiometricType.face)) {
        _log('❌ BiometricService: التعرف على الوجه غير متوفر');
        return null;
      }

      _log('👤 BiometricService: بدء عملية التحقق من الوجه...');
      _log('👤 BiometricService: السبب: $reason');

      // محاولة التحقق من الوجه
      final result = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      _log('👤 BiometricService: نتيجة التحقق من الوجه: $result');

      if (result) {
        _log('✅ BiometricService: تم التحقق من الوجه بنجاح، إنشاء بيانات...');

        final biometricData = {
          'type': 'face',
          'timestamp': DateTime.now().toIso8601String(),
          'device': 'Flutter Mobile App',
          'registered': true,
          'reason': reason,
        };

        final encodedData =
            base64Encode(utf8.encode(json.encode(biometricData)));
        _log(
            '✅ BiometricService: تم إنشاء بيانات الوجه، الطول: ${encodedData.length}');

        return encodedData;
      } else {
        _log('❌ BiometricService: فشل في التحقق من الوجه');
        return null;
      }
    } catch (e) {
      _log('💥 BiometricService: خطأ في تسجيل الوجه: $e');
      return null;
    }
  }

  // التحقق من البصمة المسجلة
  static Future<bool> verifyBiometric(
      String biometricData, String reason) async {
    try {
      final biometricsAvailable = await canCheckBiometrics();
      if (!biometricsAvailable) {
        _log('❌ BiometricService: البصمة غير متوفرة في هذا الجهاز');
        return false;
      }

      // في التطبيق الحقيقي، ستقوم بمقارنة البصمة المسجلة مع البصمة المدخلة
      final result = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (result) {
        // هنا يمكنك إضافة منطق إضافي لمقارنة البصمة
        return true;
      }

      return false;
    } catch (e) {
      _log('💥 BiometricService: خطأ في التحقق من البصمة: $e');
      return false;
    }
  }

  // حذف البصمة المحلية (إذا كانت محفوظة محلياً)
  static Future<bool> deleteLocalBiometric() async {
    try {
      // في التطبيق الحقيقي، ستقوم بحذف البصمة المحفوظة محلياً
      _log('✅ BiometricService: تم حذف البصمة المحلية');
      return true;
    } catch (e) {
      _log('💥 BiometricService: خطأ في حذف البصمة المحلية: $e');
      return false;
    }
  }

  // الحصول على نوع المصادقة كـ String
  static String getBiometricTypeString(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'الوجه';
      case BiometricType.fingerprint:
        return 'البصمة';
      case BiometricType.iris:
        return 'القزحية';
      default:
        return 'غير معروف';
    }
  }

  // الحصول على جميع أنواع المصادقة المتاحة كـ String
  static Future<String> getAvailableBiometricsString() async {
    final biometrics = await getAvailableBiometrics();
    if (biometrics.isEmpty) {
      return 'لا توجد وسائل مصادقة بيومترية متاحة';
    }

    final types =
        biometrics.map((type) => getBiometricTypeString(type)).toList();
    return types.join('، ');
  }

  // التحقق من أن الجهاز يدعم البصمة
  static Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException catch (e) {
      _log('خطأ في التحقق من دعم الجهاز: $e');
      return false;
    }
  }

  // التحقق من أن المستخدم مسجل البصمة
  static Future<bool> hasEnrolledBiometrics() async {
    try {
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();
      return availableBiometrics.isNotEmpty;
    } on PlatformException catch (e) {
      _log('خطأ في التحقق من البصمة المسجلة: $e');
      return false;
    }
  }
}
