import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../models/biometric.dart';

class BiometricApiService {
  static final BiometricApiService _instance = BiometricApiService._internal();
  factory BiometricApiService() => _instance;
  BiometricApiService._internal();

  // دالة تسجيل الأحداث للتطوير
  static void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  // تسجيل البصمة للموظف
  static Future<BiometricResponse> registerBiometric(
      int clientId, BiometricModel biometric) async {
    try {
      _log('🔐 بدء تسجيل البصمة...');
      _log('👤 رقم الموظف: ${biometric.employeeNumber}');
      _log('🏢 ClientID: $clientId');
      _log('🔐 نوع البصمة: ${biometric.biometricType}');

      final url = ApiConfig.getBiometricRegisterUrl(clientId);
      _log('🔗 URL: $url');

      final response = await http
          .post(
            Uri.parse(url),
            headers: ApiConfig.headers,
            body: jsonEncode(biometric.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      _log('📡 Response Status: ${response.statusCode}');
      _log('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('✅ تم تسجيل البصمة بنجاح');
        return BiometricResponse.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        _log('❌ خطأ في تسجيل البصمة: ${errorData['Message']}');
        return BiometricResponse(
          success: false,
          message: errorData['Message'] ?? 'فشل في تسجيل البصمة',
        );
      }
    } catch (e) {
      _log('💥 خطأ في الاتصال: $e');
      return BiometricResponse(
        success: false,
        message: 'خطأ في الاتصال: $e',
      );
    }
  }

  // التحقق من وجود بصمة مسجلة
  static Future<BiometricCheckResponse> checkBiometric(
      int clientId, String employeeNumber) async {
    try {
      _log('🔍 التحقق من وجود البصمة...');
      _log('👤 رقم الموظف: $employeeNumber');
      _log('🏢 ClientID: $clientId');

      final url = '${ApiConfig.getBiometricCheckUrl(clientId)}/$employeeNumber';
      _log('🔗 URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      _log('📡 Response Status: ${response.statusCode}');
      _log('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('✅ تم التحقق من البصمة بنجاح');
        return BiometricCheckResponse.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        _log('❌ خطأ في التحقق من البصمة: ${errorData['Message']}');
        return BiometricCheckResponse(
          success: false,
          message: errorData['Message'] ?? 'فشل في التحقق من البصمة',
          hasBiometric: false,
        );
      }
    } catch (e) {
      _log('💥 خطأ في الاتصال: $e');
      return BiometricCheckResponse(
        success: false,
        message: 'خطأ في الاتصال: $e',
        hasBiometric: false,
      );
    }
  }

  // حذف البصمة
  static Future<BiometricResponse> deleteBiometric(
      int clientId, String employeeNumber) async {
    try {
      _log('🗑️ بدء حذف البصمة...');
      _log('👤 رقم الموظف: $employeeNumber');
      _log('🏢 ClientID: $clientId');

      final url =
          '${ApiConfig.getBiometricDeleteUrl(clientId)}/$employeeNumber';
      _log('🔗 URL: $url');

      final response = await http.delete(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      _log('📡 Response Status: ${response.statusCode}');
      _log('📄 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _log('✅ تم حذف البصمة بنجاح');
        return BiometricResponse.fromJson(data);
      } else {
        final errorData = jsonDecode(response.body);
        _log('❌ خطأ في حذف البصمة: ${errorData['Message']}');
        return BiometricResponse(
          success: false,
          message: errorData['Message'] ?? 'فشل في حذف البصمة',
        );
      }
    } catch (e) {
      _log('💥 خطأ في الاتصال: $e');
      return BiometricResponse(
        success: false,
        message: 'خطأ في الاتصال: $e',
      );
    }
  }
}
