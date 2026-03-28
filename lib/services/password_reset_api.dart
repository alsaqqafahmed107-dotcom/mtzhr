import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class PasswordResetApi {
  static Map<String, dynamic> _normalizeResponse(String body) {
    try {
      final Map<String, dynamic> data = json.decode(body);
      return {
        'success': data['success'] ?? data['Success'] ?? false,
        'message': data['message'] ?? data['Message'] ?? '',
      };
    } catch (e) {
      return {'success': false, 'message': 'Format Error: $body'};
    }
  }

  static Future<Map<String, dynamic>> requestOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/employee/forgot-password'),
        headers: ApiConfig.headers,
        body: json.encode({'Email': email}),
      );
      return _normalizeResponse(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> verifyOtp(String email, String code) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/employee/verify-otp'),
        headers: ApiConfig.headers,
        body: json.encode({'Email': email, 'OTP': code}),
      );
      return _normalizeResponse(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> resetPassword(String email, String otp, String password) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/employee/reset-password'),
        headers: ApiConfig.headers,
        body: json.encode({
          'Email': email,
          'OTP': otp,
          'NewPassword': password,
          'ConfirmPassword': password,
        }),
      );
      return _normalizeResponse(response.body);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
