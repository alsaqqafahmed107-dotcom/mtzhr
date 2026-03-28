import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'lib/config/api_config.dart';

// دالة تسجيل الأحداث للتطوير
void _log(String message) {
  if (kDebugMode) {
    print(message);
  }
}

void main() async {
  _log('🧪 بدء اختبار API...');

  // بيانات الاتصال
  final String baseUrl = ApiConfig.baseUrl;
  const String loginEndpoint = ApiConfig.loginEndpoint;

  // الحسابات التجريبية
  final List<Map<String, String>> testAccounts = [
    {'email': 'admin@example.com', 'password': 'admin123'},
    {'email': 'employee@example.com', 'password': 'employee123'},
  ];

  for (final account in testAccounts) {
    _log('\n🔐 اختبار الحساب: ${account['email']}');

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl$loginEndpoint'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: json.encode({
              'email': account['email'],
              'password': account['password'],
            }),
          )
          .timeout(const Duration(seconds: 30));

      _log('📦 Body: ${json.encode({
            'email': account['email'],
            'password': account['password'],
          })}');

      _log('📡 Status Code: ${response.statusCode}');
      _log('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _log('✅ نجح تسجيل الدخول!');
          _log('👤 الموظف: ${data['employee']?['name'] ?? 'غير محدد'}');
        } else {
          _log('❌ فشل تسجيل الدخول: ${data['message']}');
        }
      } else {
        _log('❌ خطأ في الاستجابة: ${response.statusCode}');
      }
    } catch (e) {
      _log('💥 Error: $e');
    }
  }
}
