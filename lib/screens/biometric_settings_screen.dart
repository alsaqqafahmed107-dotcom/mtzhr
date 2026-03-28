import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import '../services/biometric_service.dart';

class BiometricSettingsScreen extends StatefulWidget {
  const BiometricSettingsScreen({super.key});

  @override
  State<BiometricSettingsScreen> createState() =>
      _BiometricSettingsScreenState();
}

class _BiometricSettingsScreenState extends State<BiometricSettingsScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isLoading = true;
  bool _canCheckBiometrics = false;
  bool _isDeviceSupported = false;
  List<BiometricType> _availableBiometrics = [];
  String? _errorMessage;

  // دالة تسجيل الأحداث للتطوير
  void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  @override
  void initState() {
    super.initState();
    _checkBiometricStatus();
  }

  Future<void> _checkBiometricStatus() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      _log('🔍 فحص حالة البصمة...');

      // التحقق من إمكانية فحص البصمة
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      _log('🔍 canCheckBiometrics: $canCheckBiometrics');

      // التحقق من دعم الجهاز
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      _log('🔍 isDeviceSupported: $isDeviceSupported');

      // جلب أنواع البصمة المتوفرة
      final availableBiometrics = await _localAuth.getAvailableBiometrics();
      _log('🔍 availableBiometrics: $availableBiometrics');

      setState(() {
        _canCheckBiometrics = canCheckBiometrics;
        _isDeviceSupported = isDeviceSupported;
        _availableBiometrics = availableBiometrics;
        _isLoading = false;
      });
    } catch (e) {
      _log('💥 خطأ في فحص حالة البصمة: $e');
      setState(() {
        _errorMessage = 'خطأ في فحص حالة البصمة: $e';
        _isLoading = false;
      });
    }
  }

  String _getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.fingerprint:
        return 'البصمة';
      case BiometricType.face:
        return 'التعرف على الوجه';
      case BiometricType.iris:
        return 'قزحية العين';
      default:
        return type.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات البصمة'),
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkBiometricStatus,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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

                  // حالة الجهاز
                  _buildStatusCard(),
                  const SizedBox(height: 16),

                  // أنواع البصمة المتوفرة
                  _buildAvailableBiometricsCard(),
                  const SizedBox(height: 16),

                  // تعليمات التفعيل
                  _buildInstructionsCard(),
                  const SizedBox(height: 16),

                  // اختبار البصمة
                  _buildTestCard(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'حالة الجهاز',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildStatusRow(
              'دعم الجهاز للبصمة',
              _isDeviceSupported,
              Icons.phone_android,
            ),
            _buildStatusRow(
              'توفر البصمة',
              _canCheckBiometrics,
              Icons.fingerprint,
            ),
            _buildStatusRow(
              'الحالة العامة',
              _canCheckBiometrics && _isDeviceSupported,
              Icons.check_circle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String title, bool status, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: status ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status ? Colors.green.shade100 : Colors.red.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status ? 'متوفر' : 'غير متوفر',
              style: TextStyle(
                color: status ? Colors.green.shade700 : Colors.red.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailableBiometricsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'أنواع البصمة المتوفرة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (_availableBiometrics.isEmpty)
              const Text(
                'لا توجد أنواع بصمة متوفرة في هذا الجهاز',
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ..._availableBiometrics.map((type) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _getBiometricTypeName(type),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تعليمات تفعيل البصمة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (!_isDeviceSupported)
              _buildInstructionItem(
                '1. تأكد من أن جهازك يدعم البصمة',
                'بعض الأجهزة القديمة لا تدعم البصمة',
                Icons.warning,
                Colors.orange,
              )
            else if (!_canCheckBiometrics)
              _buildInstructionItem(
                '1. اذهب إلى إعدادات الجهاز',
                'Settings > Security > Biometrics',
                Icons.settings,
                Colors.blue,
              )
            else if (_availableBiometrics.isEmpty)
              _buildInstructionItem(
                '1. قم بإعداد البصمة في إعدادات الجهاز',
                'Settings > Security > Fingerprint/Face Recognition',
                Icons.fingerprint,
                Colors.green,
              )
            else
              _buildInstructionItem(
                '✅ البصمة مفعلة وجاهزة للاستخدام',
                'يمكنك الآن تسجيل البصمة في التطبيق',
                Icons.check_circle,
                Colors.green,
              ),
            const SizedBox(height: 8),
            _buildInstructionItem(
              '2. أضف بصمة أو وجه في إعدادات الجهاز',
              'Settings > Security > Add Fingerprint/Face',
              Icons.add_circle,
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildInstructionItem(
              '3. عد إلى التطبيق وجرب تسجيل البصمة',
              'ستتمكن من تسجيل البصمة الآن',
              Icons.arrow_back,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionItem(
      String title, String subtitle, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختبار البصمة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'اضغط على الزر أدناه لاختبار البصمة:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _canCheckBiometrics ? _testBiometric : null,
                icon: const Icon(Icons.fingerprint),
                label: const Text(
                  'اختبار البصمة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
          ],
        ),
      ),
    );
  }

  Future<void> _testBiometric() async {
    try {
      final result = await BiometricService.authenticateForAttendance(
        isCheckIn: true,
        employeeName: 'اختبار',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result
                  ? '✅ تم التحقق من البصمة بنجاح'
                  : '❌ فشل في التحقق من البصمة',
            ),
            backgroundColor: result ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ في اختبار البصمة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
