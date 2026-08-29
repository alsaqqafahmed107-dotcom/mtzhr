import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';

class FaceApiService {
  // ========================================================================
  // 🛡️ الحماية الفائقة (Global Success Flag) — لتفادي مشاكل Navigator.pop
  // التي قد تفشل لأي سبب (Hot Restart, سياق قديم، إغلاق سريع جداً للشاشة،
  // أو أي استثناء غير متوقع في مسار Flutter).
  //
  // المبدأ: فور وصول رد الـ API بنجاح (Success=true) — نضبط هذا العلم
  // على (LastSuccess=true, LastEmployeeNumber, LastTimestamp).
  // ثم في attendance_screen: حتى لو كان navigationResult=false/null
  // (بسبب أي خلل Navigator) — نتحقق من هذا العلم + رقم الموظف + وقت
  // صالح (آخر 2 دقيقة) → نعتبر التحقق ناجحاً أيضاً.
  // ========================================================================
  static bool _lastSessionSuccess = false;
  static String? _lastSessionEmployeeNumber;
  static String? _lastSessionKind;
  static DateTime? _lastSessionTimestamp;
  static const Duration _lastSessionValidity = Duration(minutes: 5); // ⚡ زيادة من 2 إلى 5 دقائق لمرونة أكبر

  static String _newTraceId() {
    final timePart = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = StringBuffer();
    final now = DateTime.now().microsecondsSinceEpoch;
    for (int i = 0; i < 6; i++) {
      rnd.write(chars[(now + i * 7) % chars.length]);
    }
    return '$timePart-$rnd';
  }

  static void markLastFaceSessionSuccessful({
    required String employeeNumber,
    String sessionKind = 'verification',
  }) {
    _lastSessionSuccess = true;
    _lastSessionEmployeeNumber = employeeNumber;
    _lastSessionKind = sessionKind;
    _lastSessionTimestamp = DateTime.now();
    if (kDebugMode) {
      final tid = _newTraceId();
      print('🛡️ [Failsafe:$tid] تم ضبط علامة النجاح العالمية للموظف $employeeNumber | النوع=$sessionKind | صلاحية=${_lastSessionValidity.inMinutes}د');
    }
  }

  static bool verifyLastFaceSessionSuccess({
    required String employeeNumber,
    String? requiredSessionKind,
  }) {
    final tid = _newTraceId();
    if (!_lastSessionSuccess) { if (kDebugMode) print('🛡️ [Failsafe:$tid] العلامة العالمية = FALSE'); return false; }
    if (_lastSessionEmployeeNumber != employeeNumber) { if (kDebugMode) print('🛡️ [Failsafe:$tid] عدم تطابق رقم الموظف (المطلوب=$employeeNumber / الحالي=$_lastSessionEmployeeNumber)'); return false; }
    if (requiredSessionKind != null && _lastSessionKind != requiredSessionKind) {
      if (kDebugMode) print('🛡️ [Failsafe:$tid] نوع الجلسة غير مطابق (المطلوب=$requiredSessionKind / الحالي=$_lastSessionKind)');
      return false;
    }
    if (_lastSessionTimestamp == null) return false;
    final age = DateTime.now().difference(_lastSessionTimestamp!);
    final valid = age <= _lastSessionValidity;
    if (kDebugMode) {
      print('🛡️ [Failsafe:$tid] فحص العلامة العالمية: ${valid ? "✅ صالحة" : "❌ منتهية"} — عمر الجلسة: ${age.inSeconds}s (الحد ${_lastSessionValidity.inMinutes}د)');
    }
    return valid;
  }

  static void clearLastFaceSession() {
    _lastSessionSuccess = false;
    _lastSessionEmployeeNumber = null;
    _lastSessionKind = null;
    _lastSessionTimestamp = null;
  }

  // Public getters للـ Diagnostics في شاشة الحضور:
  static bool get debugLastSessionSuccess => _lastSessionSuccess;
  static String? get debugLastSessionEmployee => _lastSessionEmployeeNumber;
  static String? get debugLastSessionKind => _lastSessionKind;
  static DateTime? get debugLastSessionTimestamp => _lastSessionTimestamp;

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
    String tid = _newTraceId();
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        _log('🚀 [T$tid] طلب HTTP (محاولة $attempt/$maxAttempts) - محاولة إرسال...');
        final response = await request().timeout(timeout);
        final status = response.statusCode;
        final len = response.body.length;
        if (response.statusCode == 200) {
          _log('✅ [T$tid] HTTP 200 OK | طول الرد: $len بايت');
          return jsonDecode(response.body);
        }

      try {
          _log('⚠️ [T$tid] HTTP $status (ليس 200) | طول الرد: $len بايت');
          final decoded = jsonDecode(response.body);
          // 🛡️ إضافة StatusCode بشكل صريح إلى النتيجة (حتى لو كان الرد JSON صالح)
          if (decoded is Map<String, dynamic>) {
            decoded['StatusCode'] = decoded['StatusCode'] ?? status;
            return decoded;
          }
          return decoded;
        } catch (_) {
          return {
            'Success': false,
            'Message': 'خطأ في الاستجابة من السيرفر: ${response.statusCode}',
            'StatusCode': status, // 🛡️ مضاف بشكل صريح لكشف 404 بدقة
            'RawBodyLength': len,
          };
        }
      } on TimeoutException catch (e) {
        _log('⏱️ [T$tid] Timeout (محاولة $attempt/$maxAttempts): $e');
        if (attempt < maxAttempts) {
          await Future.delayed(
            Duration(milliseconds: ApiConfig.retryDelay * attempt),
          );
          continue;
        }
        return {
          'Success': false,
          'Message': 'انتهت مهلة الاتصال. تأكد من الاتصال بالسيرفر ثم أعد المحاولة',
        };
      } catch (e) {
        _log('💥 [T$tid] خطأ HTTP (محاولة $attempt/$maxAttempts): $e');
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

  static Uri _uri(String url) => Uri.parse(ApiConfig.wrapUrlForWeb(url));

  /// جلب حالة بصمة الوجه للموظف (هل هي مطلوبة؟ هل مسجلة؟)
  static Future<Map<String, dynamic>> getFaceStatus(int clientId, String employeeNumber) async {
    final url = ApiConfig.getFaceStatusUrl(clientId, employeeNumber);
    _log('🔍 Checking status: $url');

    return _requestJsonWithRetry(
      request: () => http.get(_uri(url), headers: ApiConfig.headers),
      timeout: const Duration(seconds: 30),
      maxAttempts: 2,
    );
  }

  /// جلب قائمة الموظفين مع حالة بصمة الوجه (للإدارة)
  static Future<Map<String, dynamic>> getEmployeesFaceStatus(int clientId) async {
    final url = ApiConfig.getFaceEmployeesUrl(clientId);
    _log('📋 Fetching face employees: $url');

    return _requestJsonWithRetry(
      request: () => http.get(_uri(url), headers: ApiConfig.headers),
      timeout: const Duration(seconds: 60),
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
    _log('🚀 Enroll face: Emp=$employeeNumber | Client=$clientId | طول الصورة (Base64)=${imageBase64.length ~/ 1024}KB');

    final body = {
      'EmployeeNumber': employeeNumber,
      'ImageBase64': imageBase64,
      'DeviceInfo': deviceInfo ?? 'Flutter App',
    };

    return _requestJsonWithRetry(
      request: () => http.post(
        _uri(url),
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
    _log('👤 Verify face: Emp=$employeeNumber | Client=$clientId | طول الصورة (Base64)=${imageBase64.length ~/ 1024}KB');

    final body = {
      'EmployeeNumber': employeeNumber,
      'ImageBase64': imageBase64,
      'DeviceInfo': deviceInfo ?? 'Flutter App',
    };

    return _requestJsonWithRetry(
      request: () => http.post(
        _uri(url),
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
      request: () => http.delete(_uri(url), headers: ApiConfig.headers),
      timeout: const Duration(seconds: 30),
      maxAttempts: 2,
    );
  }

  // ========================================================================
  // 🆕 دوال الواجهة الجديدة (RESTRUCTURED FLOW حسب المتطلبات):
  // ------------------------------------------------------------------------
  // - Enrollment: حفظ صورة الوجه مباشرة في جدول Users_Employees
  //               (NO LIVENESS - فقط تحقق وجود وجه + زاوية مناسبة)
  // - Verification: أثناء الحضور/الانصراف فقط (WITH LIVENESS + MATCH)
  //                 مطابقة الوجه الملتقط ضد الصورة المحفوظة في المستخدمين
  // ========================================================================

  // ================================================================
  // 🛡️ نظام الـ Fallback الذكي لحماية التدفق من خطأ 404:
  //    -> إذا كانت نقطة النهاية الجديدة غير موجودة على السيرفر (HTTP 404)
  //       يتم التبديل التلقائي إلى الـ Endpoint القديم المقابل (للإرث).
  // ================================================================
  static bool _isNotFound404(Map<String, dynamic> result) {
    if (result['Success'] == true) return false;
    final msg = (result['Message'] ?? '').toString();
    final code = result['StatusCode'] ?? result['statusCode'] ?? 0;
    if (code == 404) return true;
    return msg.contains('404') ||
        msg.toLowerCase().contains('not found');
  }

  /// 🆕 حفظ صورة الوجه في جدول Users_Employees (خلال التسجيل - لا فحص حياة)
  static Future<Map<String, dynamic>> saveEmployeeFaceImage({
    required int clientId,
    required String employeeNumber,
    required String imageBase64,
    String? deviceInfo,
  }) async {
    final url = ApiConfig.getSaveEmployeeFaceImageUrl(clientId);
    _log('💾 [NEW FLOW] Save Employee Face Image: Emp=$employeeNumber | Client=$clientId | حجم الصورة (Base64)=${imageBase64.length ~/ 1024}KB');

    final body = {
      'EmployeeNumber': employeeNumber,
      'ImageBase64': imageBase64,
      'DeviceInfo': deviceInfo ?? 'Flutter App (Enrollment, No Liveness)',
      'ConsentProvided': true,
      'ImagePurpose': 'EMPLOYEE_PROFILE_FACE_TEMPLATE',
      'RetentionPolicyDays': 365 * 5,
    };

    final newResult = await _requestJsonWithRetry(
      request: () => http.post(
        _uri(url),
        headers: ApiConfig.headers,
        body: jsonEncode(body),
      ),
      timeout: const Duration(seconds: 120),
      maxAttempts: 2,
    );

    // 🔄 🛡️ Fallback: إذا لم يكن الـ Endpoint الجديد منشور بعد → استخدم القديم
    if (_isNotFound404(newResult)) {
      _log('🔄 [FALLBACK] ❌ الـ Endpoint الجديد (save) غير موجود (404) — التبديل التلقائي إلى enrollFace القديم (biometric/face/enroll)...');
      return enrollFace(
        clientId: clientId,
        employeeNumber: employeeNumber,
        imageBase64: imageBase64,
        deviceInfo: deviceInfo,
      );
    }
    return newResult;
  }

  /// 🆕 جلب حالة صورة الوجه للموظف من جدول Users_Employees (هل الصورة موجودة؟)
  static Future<Map<String, dynamic>> getEmployeeFaceImageStatus(
    int clientId,
    String employeeNumber,
  ) async {
    final url = ApiConfig.getEmployeeFaceImageStatusUrl(clientId, employeeNumber);
    _log('🔍 [NEW FLOW] Checking Employee Face Image Status: $url');

    final newResult = await _requestJsonWithRetry(
      request: () => http.get(_uri(url), headers: ApiConfig.headers),
      timeout: const Duration(seconds: 30),
      maxAttempts: 2,
    );

    // 🔄 🛡️ Fallback: إذا لم يكن الـ Endpoint الجديد منشور بعد
    if (_isNotFound404(newResult)) {
      _log('🔄 [FALLBACK] ❌ الـ Endpoint الجديد (status) غير موجود (404) — التبديل التلقائي إلى getFaceStatus القديم (biometric/face/status)...');
      return getFaceStatus(clientId, employeeNumber);
    }
    return newResult;
  }

  /// 🆕 التحقق من الوجه أثناء الحضور/الانصراف (مع فحص الحياة + مطابقة ضد صورة المستخدم المخزنة)
  static Future<Map<String, dynamic>> verifyFaceWithStoredImage({
    required int clientId,
    required String employeeNumber,
    required String imageBase64,
    String? deviceInfo,
    double? livenessScore,
    int? challengesCompleted,
    double? spoofRisk,
  }) async {
    final url = ApiConfig.getVerifyFaceWithStoredImageUrl(clientId);
    _log('👤 [NEW FLOW] Verify Face (with Stored Image + Liveness): Emp=$employeeNumber | Client=$clientId | حجم الصورة=${imageBase64.length ~/ 1024}KB | Liveness=${livenessScore?.toStringAsFixed(2) ?? "N/A"}');

    final body = {
      'EmployeeNumber': employeeNumber,
      'ImageBase64': imageBase64,
      'DeviceInfo': deviceInfo ?? 'Flutter App (Attendance Verification)',
      'LivenessScore': livenessScore,
      'ChallengesCompleted': challengesCompleted,
      'SpoofRiskPercentage': spoofRisk,
      'VerificationContext': 'ATTENDANCE_CHECKPOINT',
      'MatchSource': 'USERS_EMPLOYEES_STORED_IMAGE',
    };

    final newResult = await _requestJsonWithRetry(
      request: () => http.post(
        _uri(url),
        headers: ApiConfig.headers,
        body: jsonEncode(body),
      ),
      timeout: const Duration(seconds: 120),
      maxAttempts: 2,
    );

    // 🔄 🛡️ Fallback: إذا لم يكن الـ Endpoint الجديد منشور بعد
    if (_isNotFound404(newResult)) {
      _log('🔄 [FALLBACK] ❌ الـ Endpoint الجديد (verify) غير موجود (404) — التبديل التلقائي إلى verifyFace القديم (biometric/face/verify)...');
      return verifyFace(
        clientId: clientId,
        employeeNumber: employeeNumber,
        imageBase64: imageBase64,
        deviceInfo: deviceInfo,
      );
    }
    return newResult;
  }
}
