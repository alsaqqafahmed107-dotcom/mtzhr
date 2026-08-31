import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'attendance_screen.dart';

class AuthenticationMethodScreen extends StatefulWidget {
  final String employeeNumber;
  final int clientId;
  final bool isCheckIn;
  final String? employeeName;

  const AuthenticationMethodScreen({
    super.key,
    required this.employeeNumber,
    required this.clientId,
    required this.isCheckIn,
    this.employeeName,
  });

  @override
  State<AuthenticationMethodScreen> createState() =>
      _AuthenticationMethodScreenState();
}

class _AuthenticationMethodScreenState
    extends State<AuthenticationMethodScreen> {
  bool _isLoading = false;
  final bool _gpsAvailable = true;
  final bool _faceAvailable = true;

  // دالة تسجيل الأحداث للتطوير
  void _log(String message) {
    if (kDebugMode) {
      print(message);
    }
  }

  @override
  void initState() {
    super.initState();
    _checkAvailableMethods();
  }

  Future<void> _checkAvailableMethods() async {
    try {
      setState(() {
        _isLoading = true;
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      _log('خطأ في التحقق من الطرق المتاحة: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getMethodIcon(String method) {
    switch (method) {
      case 'GPS':
        return '📍';
      case 'FACE':
        return '👤';
      default:
        return '❓';
    }
  }

  String _getMethodDescription(String method) {
    switch (method) {
      case 'GPS':
        return 'سيتم تحديد الموقع الجغرافي تلقائياً كجزء من عملية الحضور';
      case 'FACE':
        return 'سيتم فتح الكاميرا لتسجيل الوجه أو التحقق منه قبل الحضور والانصراف';
      default:
        return 'طريقة غير معروفة';
    }
  }

  void _selectMethod(String method) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendanceScreen(
          employeeNumber: widget.employeeNumber,
          clientId: widget.clientId,
          isCheckIn: widget.isCheckIn,
          authenticationMethod: method,
          employeeName: widget.employeeName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isCheckIn
              ? 'اختر طريقة تسجيل الحضور'
              : 'اختر طريقة تسجيل الانصراف',
        ),
        backgroundColor: const Color(0xFF0EA5E9),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF0EA5E9).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الموظف: ${widget.employeeName ?? widget.employeeNumber}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'رقم الموظف: ${widget.employeeNumber}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.isCheckIn ? 'تسجيل الحضور' : 'تسجيل الانصراف',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'طريقة التحقق المعتمدة:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A34A).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF16A34A).withOpacity(0.25),
                      ),
                    ),
                    child: const Text(
                      'سيتم استخدام بصمة الوجه فقط. إذا لم تكن صورة الوجه مسجلة لهذا الموظف فسيتم فتح شاشة تسجيل الوجه أولاً، ثم تنفيذ التحقق من الوجه قبل السماح بالحضور أو الانصراف.',
                      style: TextStyle(fontSize: 14, height: 1.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: 2,
                      itemBuilder: (context, index) {
                        final method = ['GPS', 'FACE'][index];
                        final isSelected =
                            [_gpsAvailable, _faceAvailable][index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: isSelected ? 4 : 2,
                          color: isSelected
                              ? const Color(0xFF0EA5E9).withOpacity(0.1)
                              : null,
                          child: InkWell(
                            onTap: () {
                              _selectMethod(method);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF0EA5E9)
                                          : Colors.grey.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                    child: Center(
                                      child: Text(
                                        _getMethodIcon(method),
                                        style: const TextStyle(fontSize: 24),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          method,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? const Color(0xFF0EA5E9)
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _getMethodDescription(method),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF0EA5E9),
                                      size: 24,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _gpsAvailable || _faceAvailable
                          ? () => _selectMethod('FACE')
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'بدء التحقق بالوجه',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
