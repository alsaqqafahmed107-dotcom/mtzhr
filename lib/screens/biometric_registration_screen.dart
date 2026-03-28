import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/biometric.dart';
import '../services/biometric_api_service.dart';
import '../services/biometric_service.dart';
import 'biometric_settings_screen.dart';

class BiometricRegistrationScreen extends StatefulWidget {
  final String employeeNumber;
  final int clientId;
  final String? employeeName;

  const BiometricRegistrationScreen({
    super.key,
    required this.employeeNumber,
    required this.clientId,
    this.employeeName,
  });

  @override
  State<BiometricRegistrationScreen> createState() =>
      _BiometricRegistrationScreenState();
}

class _BiometricRegistrationScreenState
    extends State<BiometricRegistrationScreen> {
  bool _isProcessing = false;
  String? _errorMessage;
  String? _successMessage;
  bool _hasBiometric = false;
  String? _debugInfo;

  void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  @override
  void initState() {
    super.initState();
    _checkExistingBiometric();
  }

  Future<void> _checkExistingBiometric() async {
    try {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
        _debugInfo = null;
      });

      final canCheck = await BiometricService.canCheckBiometrics();
      final available = await BiometricService.getAvailableBiometrics();
      setState(() {
        _debugInfo = 'canCheckBiometrics: '
            '[32m$canCheck[0m\navailableBiometrics: '
            '\u001b[34m$available\u001b[0m';
      });

      final response = await BiometricApiService.checkBiometric(
        widget.clientId,
        widget.employeeNumber,
      );

      setState(() {
        _hasBiometric = response.hasBiometric;
        _isProcessing = false;
      });

      if (response.hasBiometric) {
        setState(() {
          _errorMessage = 'البصمة مسجلة مسبقاً لهذا الموظف';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في التحقق من البصمة: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _registerFingerprint() async {
    try {
      _log('🔐 بدء تسجيل البصمة...');
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
        _successMessage = null;
        _debugInfo = null;
      });

      final canCheckBiometrics = await BiometricService.canCheckBiometrics();
      final availableBiometrics =
          await BiometricService.getAvailableBiometrics();
      setState(() {
        _debugInfo = 'canCheckBiometrics: '
            '[32m$canCheckBiometrics[0m\navailableBiometrics: '
            '\u001b[34m$availableBiometrics\u001b[0m';
      });

      if (!canCheckBiometrics || availableBiometrics.isEmpty) {
        setState(() {
          _errorMessage =
              'الجهاز يدعم البصمة أو الوجه لكن لم يتم إعداد أي بصمة أو وجه في إعدادات الجهاز. يرجى إضافة بصمة أو وجه أولاً.';
          _isProcessing = false;
        });
        return;
      }

      _log('🔐 بدء عملية تسجيل البصمة...');
      final biometricData = await BiometricService.registerFingerprint(
        'تسجيل البصمة للموظف ${widget.employeeName ?? widget.employeeNumber}',
      );

      _log(
          '📄 بيانات البصمة المستلمة: ${biometricData != null ? "موجودة" : "غير موجودة"}');

      if (biometricData == null) {
        _log('❌ فشل في الحصول على بيانات البصمة');
        setState(() {
          _errorMessage = 'فشل في تسجيل البصمة. يرجى المحاولة مرة أخرى.';
          _isProcessing = false;
        });
        return;
      }

      _log('📊 طول بيانات البصمة: ${biometricData.length}');

      _log('🌐 إرسال البيانات إلى API...');
      final biometric = BiometricModel(
        employeeNumber: widget.employeeNumber,
        biometricData: biometricData,
        biometricType: 'FINGERPRINT',
        deviceInfo: 'Flutter Mobile App',
        createdDate: DateTime.now(),
      );

      _log('👤 رقم الموظف: ${widget.employeeNumber}');
      _log('🏢 ClientID: ${widget.clientId}');
      _log('🔐 نوع البصمة: FINGERPRINT');

      final response = await BiometricApiService.registerBiometric(
        widget.clientId,
        biometric,
      );

      _log('📡 استجابة API: ${response.success} - ${response.message}');

      if (response.success) {
        _log('✅ تم تسجيل البصمة بنجاح');
        setState(() {
          _successMessage = 'تم تسجيل البصمة بنجاح';
          _hasBiometric = true;
          _isProcessing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_successMessage!),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _log('❌ فشل في تسجيل البصمة: ${response.message}');
        setState(() {
          _errorMessage = response.message;
          _isProcessing = false;
        });
      }
    } catch (e) {
      _log('💥 خطأ في تسجيل البصمة: $e');
      setState(() {
        _errorMessage = 'خطأ في تسجيل البصمة: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _registerFace() async {
    try {
      _log('👤 بدء تسجيل الوجه...');
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
        _successMessage = null;
        _debugInfo = null;
      });

      final canCheckBiometrics = await BiometricService.canCheckBiometrics();
      final availableBiometrics =
          await BiometricService.getAvailableBiometrics();
      setState(() {
        _debugInfo = 'canCheckBiometrics: '
            '[32m$canCheckBiometrics[0m\navailableBiometrics: '
            '\u001b[34m$availableBiometrics\u001b[0m';
      });

      if (!canCheckBiometrics || availableBiometrics.isEmpty) {
        setState(() {
          _errorMessage =
              'الجهاز يدعم البصمة أو الوجه لكن لم يتم إعداد أي بصمة أو وجه في إعدادات الجهاز. يرجى إضافة بصمة أو وجه أولاً.';
          _isProcessing = false;
        });
        return;
      }

      _log('👤 بدء عملية تسجيل الوجه...');
      final biometricData = await BiometricService.registerFace(
        'تسجيل الوجه للموظف ${widget.employeeName ?? widget.employeeNumber}',
      );

      _log(
          '📄 بيانات الوجه المستلمة: ${biometricData != null ? "موجودة" : "غير موجودة"}');

      if (biometricData == null) {
        _log('❌ فشل في الحصول على بيانات الوجه');
        setState(() {
          _errorMessage = 'فشل في تسجيل الوجه. يرجى المحاولة مرة أخرى.';
          _isProcessing = false;
        });
        return;
      }

      _log('📊 طول بيانات الوجه: ${biometricData.length}');

      _log('🌐 إرسال البيانات إلى API...');
      final biometric = BiometricModel(
        employeeNumber: widget.employeeNumber,
        biometricData: biometricData,
        biometricType: 'FACE',
        deviceInfo: 'Flutter Mobile App',
        createdDate: DateTime.now(),
      );

      _log('👤 رقم الموظف: ${widget.employeeNumber}');
      _log('🏢 ClientID: ${widget.clientId}');
      _log('🔐 نوع البصمة: FACE');

      final response = await BiometricApiService.registerBiometric(
        widget.clientId,
        biometric,
      );

      _log('📡 استجابة API: ${response.success} - ${response.message}');

      if (response.success) {
        _log('✅ تم تسجيل الوجه بنجاح');
        setState(() {
          _successMessage = 'تم تسجيل الوجه بنجاح';
          _hasBiometric = true;
          _isProcessing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_successMessage!),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        _log('❌ فشل في تسجيل الوجه: ${response.message}');
        setState(() {
          _errorMessage = response.message;
          _isProcessing = false;
        });
      }
    } catch (e) {
      _log('💥 خطأ في تسجيل الوجه: $e');
      setState(() {
        _errorMessage = 'خطأ في تسجيل الوجه: $e';
        _isProcessing = false;
      });
    }
  }

  Future<void> _deleteBiometric() async {
    try {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
        _successMessage = null;
      });

      final response = await BiometricApiService.deleteBiometric(
        widget.clientId,
        widget.employeeNumber,
      );

      if (response.success) {
        setState(() {
          _successMessage = 'تم حذف البصمة بنجاح';
          _hasBiometric = false;
          _isProcessing = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_successMessage!),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _errorMessage = response.message;
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في حذف البصمة: $e';
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل البصمة'),
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            if (_successMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Text(
                  _successMessage!,
                  style: TextStyle(color: Colors.green.shade700),
                ),
              ),
            if (_debugInfo != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  _debugInfo!,
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'معلومات الموظف',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'رقم الموظف: ${widget.employeeNumber}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  if (widget.employeeName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'اسم الموظف: ${widget.employeeName}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _hasBiometric
                          ? Colors.green.shade100
                          : Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _hasBiometric ? 'البصمة مسجلة' : 'البصمة غير مسجلة',
                      style: TextStyle(
                        color: _hasBiometric
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.fingerprint,
                      size: 100,
                      color: const Color(0xFF0EA5E9),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'تسجيل البصمة',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'اختر طريقة تسجيل البصمة',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (!_hasBiometric) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isProcessing ? null : _registerFingerprint,
                          icon: const Icon(Icons.fingerprint),
                          label: const Text(
                            'تسجيل البصمة',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA5E9),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _registerFace,
                          icon: const Icon(Icons.face),
                          label: const Text(
                            'تسجيل الوجه',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const BiometricSettingsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.settings),
                          label: const Text(
                            'إعدادات البصمة',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _deleteBiometric,
                          icon: const Icon(Icons.delete),
                          label: const Text(
                            'حذف البصمة',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_isProcessing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(width: 16),
                    const Text('جاري المعالجة...'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
