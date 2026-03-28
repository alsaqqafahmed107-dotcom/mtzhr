import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class FaceApiService {
  static void _log(String message) {
    if (kDebugMode) {
      print('👤 [FaceApiService] $message');
    }
  }

  static Future<Map<String, dynamic>> _requestJsonWithRetry({
    required Future<http.Response> Function() request,
    required Duration timeout,
    int maxAttempts = 3,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await request().timeout(timeout);

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }

        try {
          return jsonDecode(response.body);
        } catch (_) {
          return {
            'Success': false,
            'Message':
                'خطأ في الاستجابة من السيرفر: ${response.statusCode}',
          };
        }
      } on TimeoutException catch (e) {
        _log('⏱️ Timeout (Attempt $attempt/$maxAttempts): $e');
        if (attempt < maxAttempts) {
          await Future.delayed(
            Duration(milliseconds: ApiConfig.retryDelay * attempt),
          );
          continue;
        }
        return {
          'Success': false,
          'Message':
              'انتهت مهلة الاتصال. تأكد من الاتصال بالسيرفر ثم أعد المحاولة',
        };
      } catch (e) {
        _log('💥 Error (Attempt $attempt/$maxAttempts): $e');
        if (attempt < maxAttempts) {
          await Future.delayed(
            Duration(milliseconds: ApiConfig.retryDelay * attempt),
          );
          continue;
        }
        return {'Success': false, 'Message': 'خطأ في الاتصال: $e'};
      }
    }

    return {
      'Success': false,
      'Message': 'خطأ غير متوقع أثناء الاتصال بسيرفر الوجه',
    };
  }

  /// جلب حالة بصمة الوجه للموظف (هل هي مطلوبة؟ هل مسجلة؟)
  static Future<Map<String, dynamic>> getFaceStatus(int clientId, String employeeNumber) async {
    final url = ApiConfig.getFaceStatusUrl(clientId, employeeNumber);
    _log('🔍 Checking status: $url');

    return _requestJsonWithRetry(
      request: () => http.get(Uri.parse(url), headers: ApiConfig.headers),
      timeout: const Duration(seconds: 30),
      maxAttempts: 2,
    );
  }

  /// تسجيل بصمة الوجه (Enrollment)
  static Future<Map<String, dynamic>> enrollFace({
    required int clientId,
    required String employeeNumber,
    required String imageBase64,
    String? deviceInfo,
  }) async {
    final url = ApiConfig.getFaceEnrollUrl(clientId);
    _log('🚀 Enrolling face: $url');

    final body = {
      'EmployeeNumber': employeeNumber,
      'ImageBase64': imageBase64,
      'DeviceInfo': deviceInfo ?? 'Flutter App',
    };

    return _requestJsonWithRetry(
      request: () => http.post(
        Uri.parse(url),
        headers: ApiConfig.headers,
        body: jsonEncode(body),
      ),
      timeout: const Duration(seconds: 120),
      maxAttempts: 2,
    );
  }

  /// التحقق من بصمة الوجه (Verification)
  static Future<Map<String, dynamic>> verifyFace({
    required int clientId,
    required String employeeNumber,
    required String imageBase64,
    String? deviceInfo,
  }) async {
    final url = ApiConfig.getFaceVerifyUrl(clientId);
    _log('👤 Verifying face: $url');

    final body = {
      'EmployeeNumber': employeeNumber,
      'ImageBase64': imageBase64,
      'DeviceInfo': deviceInfo ?? 'Flutter App',
    };

    return _requestJsonWithRetry(
      request: () => http.post(
        Uri.parse(url),
        headers: ApiConfig.headers,
        body: jsonEncode(body),
      ),
      timeout: const Duration(seconds: 120),
      maxAttempts: 2,
    );
  }

  /// إعادة تعيين بصمة الوجه
  static Future<Map<String, dynamic>> resetFace(int clientId, String employeeNumber) async {
    final url = ApiConfig.getFaceResetUrl(clientId, employeeNumber);
    _log('♻️ Resetting face: $url');

    return _requestJsonWithRetry(
      request: () => http.delete(Uri.parse(url), headers: ApiConfig.headers),
      timeout: const Duration(seconds: 30),
      maxAttempts: 2,
    );
  }
}
