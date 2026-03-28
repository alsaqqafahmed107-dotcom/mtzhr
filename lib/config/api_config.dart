import 'package:flutter/foundation.dart';
import 'api_discovery.dart';

class ApiConfig {
  // الرابط الأساسي للـ API - متغير
  static String _baseUrl = 'http://192.168.1.162:5000';
  // static String _baseUrl =
  // 'http://www.perfect-solutions.net/HR/API:334'; // تم التغيير من localhost لدعم الهاتف الحقيقي
  // 'http://www.perfect-solutions.net:334/HR/API'; // تم التغيير من localhost لدعم الهاتف الحقيقي
  static bool _isInitialized = false;

  // دالة للحصول على الرابط الأساسي
  static String get baseUrl => _normalizeBaseUrl(_baseUrl);

  // بادئة وكيل الويب الاختياري لتجاوز CORS في بيئة التطوير
  // مثال التشغيل:
  // flutter run -d chrome --dart-define=WEB_PROXY_PREFIX=https://cors.isomorphic-git.org
  static const String webProxyPrefix =
      String.fromEnvironment('WEB_PROXY_PREFIX', defaultValue: '');

  // يغلّف عنواناً كاملاً عبر وكيل الويب إن تم تعريفه
  static String wrapUrlForWeb(String url) {
    if (!kIsWeb) return url;
    final prefix = webProxyPrefix.trim();
    if (prefix.isEmpty) return url;
    if (prefix.endsWith('/')) {
      return '$prefix$url';
    }
    return '$prefix/$url';
  }

  static String _normalizeBaseUrl(String url) {
    var u = url.trim();
    u = u.replaceAll('`', '').trim();
    u = u.replaceAll(RegExp(r'\s+'), '');
    try {
      final parsed = Uri.parse(u);
      if (parsed.scheme.isEmpty || parsed.host.isEmpty) {
        return u;
      }

      final segments = parsed.pathSegments.toList();
      int? extractedPort;
      if (!parsed.hasPort && segments.isNotEmpty) {
        final last = segments.last;
        final idx = last.lastIndexOf(':');
        if (idx > 0 && idx < last.length - 1) {
          final portPart = last.substring(idx + 1);
          final namePart = last.substring(0, idx);
          final maybePort = int.tryParse(portPart);
          if (maybePort != null) {
            extractedPort = maybePort;
            segments[segments.length - 1] = namePart;
          }
        }
      }

      final rebuilt = Uri(
        scheme: parsed.scheme,
        userInfo: parsed.userInfo,
        host: parsed.host,
        port: parsed.hasPort ? parsed.port : extractedPort,
        path: segments.isEmpty ? '' : '/${segments.join('/')}',
      );
      var result = rebuilt.toString();
      // إزالة أي '/' زائد في النهاية
      if (result.endsWith('/')) {
        result = result.substring(0, result.length - 1);
      }
      return result;
    } catch (_) {
      return u;
    }
  }

  // ضم المسارات بشكل صحيح لضمان عدم تكرار '/'
  static String _join(String base, String endpoint) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final e = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
    return '$b/$e';
  }

  // دالة لتهيئة النظام وجلب الرابط المحول
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🔍 جاري اكتشاف الرابط المحول...');

      _baseUrl = _normalizeBaseUrl(_baseUrl);
      final discovered = await discoverBaseUrl(_baseUrl);
      if (discovered != null && discovered.isNotEmpty) {
        _baseUrl = _normalizeBaseUrl(discovered);
        print('✅ تم اكتشاف رابط محول: $_baseUrl');
      } else {
        print('✅ تم استخدام الرابط الافتراضي: $_baseUrl');
      }

      _isInitialized = true;
    } catch (e) {
      print(
          '⚠️ فشل اكتشاف الرابط التلقائي، سيتم استخدام الرابط الافتراضي: $_baseUrl');
      print('Error: $e');
      _isInitialized = true;
    }
  }

  // دالة لإعادة تهيئة النظام
  static Future<void> reinitialize() async {
    _isInitialized = false;
    await initialize();
  }

  // أو استخدم عنوان IP المحلي إذا كان الخادم يعمل على نفس الشبكة
  // static const String baseUrl = 'http://192.168.1.100';

  // أو استخدم عنوان الخادم في الإنتاج
  // static const String baseUrl = 'https://your-domain.com';

  // نقاط النهاية (Endpoints)
  static const String loginEndpoint = '/api/employee/login';
  static const String logoutEndpoint = '/api/employee/logout';
  static const String valuesEndpoint = '/api/values';

  // معلومات قاعدة البيانات
  static const String databaseName = 'HR_ONLINE_Central_DB';
  static const String tableName = 'Users_Employees';

  // الحقول المطلوبة في جدول المستخدمين
  static const List<String> requiredFields = [
    'ID',
    'EmployeeID',
    'Name',
    'Mail',
    'Password',
    'Rules',
    'DatabaseName',
    'IsActive',
    'ClientID',
    'ModifiedDate'
  ];

  // الحسابات التجريبية المتوفرة في قاعدة البيانات
  static const Map<String, String> demoAccounts = {
    'admin@example.com': 'admin123',
    'employee@example.com': 'employee123',
  };

  // رسائل الخطأ
  static const String connectionError = 'خطأ في الاتصال بالخادم';
  static const String serverError = 'خطأ في الخادم';
  static const String invalidCredentials =
      'البريد الإلكتروني أو كلمة المرور غير صحيحة';
  static const String inactiveAccount =
      'حسابك غير نشط. يرجى التواصل مع الإدارة.';
  static const String invalidData = 'البيانات المرسلة غير صحيحة';

  // Client ID - سيتم تحديثه من بيانات تسجيل الدخول
  static const int defaultClientId = 30;

  // API Endpoints - Multi-tenant structure
  static String get loginUrl => _join(baseUrl, loginEndpoint);
  static String get logoutUrl => _join(baseUrl, logoutEndpoint);

  // Attendance endpoints with client ID
  // ملاحظة: نوع العملية يتم تحديده من خلال الـ punchState:
  // - punchState = "0" (دخول)
  // - punchState = "1" (خروج)
  static String getCheckInUrl(int clientId) =>
      _join(baseUrl, '/api/$clientId/attendance/checkin');
  static String getCheckOutUrl(int clientId) =>
      _join(baseUrl, '/api/$clientId/attendance/checkout');
  static String getEmployeeAttendanceUrl(int clientId) =>
      _join(baseUrl, '/api/$clientId/attendance/employee');
  static String getAttendanceStatsUrl(int clientId) =>
      _join(baseUrl, '/api/$clientId/attendance/stats');
  static String getEmployeeInfoUrl(int clientId) =>
      _join(baseUrl, '/api/$clientId/employee/info');

  // Biometric endpoints with client ID
  static String getBiometricRegisterUrl(int clientId) =>
      _join(baseUrl, '/api/$clientId/biometric/register');
  static String getBiometricCheckUrl(int clientId) =>
      _join(baseUrl, '/api/$clientId/biometric/check');
  static String getBiometricDeleteUrl(int clientId) =>
      _join(baseUrl, '/api/$clientId/biometric/delete');

  // Face Biometric endpoints
  static String getFaceEnrollUrl(int clientId) =>
      _join(baseUrl, '/api/$clientId/biometric/face/enroll');
  static String getFaceVerifyUrl(int clientId) =>
      _join(baseUrl, '/api/$clientId/biometric/face/verify');
  static String getFaceStatusUrl(int clientId, String empNo) =>
      _join(baseUrl, '/api/$clientId/biometric/face/status/$empNo');
  static String getFaceResetUrl(int clientId, String empNo) =>
      _join(baseUrl, '/api/$clientId/biometric/face/reset/$empNo');

  // Headers
  static const Map<String, String> headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Timeout settings
  static const int connectionTimeout = 30000; // 30 seconds
  static const int receiveTimeout = 30000; // 30 seconds

  // Retry settings
  static const int maxRetries = 3;
  static const int retryDelay = 1000; // 1 second
}
