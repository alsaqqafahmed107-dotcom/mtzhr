import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../models/attendance.dart';
import '../services/api_service.dart';
import '../services/biometric_service.dart';
import '../services/location_stability_service.dart';
import '../services/face_api_service.dart';
import 'face_enrollment_screen.dart';
import 'face_verification_screen.dart';
import 'dart:math' as math;
import '../services/language_service.dart';
import '../services/translations.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/platform_helper.dart';

class AttendanceScreen extends StatefulWidget {
  final String employeeNumber;
  final int clientId;
  final bool isCheckIn;
  final String? authenticationMethod;
  final String? employeeName;

  const AttendanceScreen({
    super.key,
    required this.employeeNumber,
    required this.clientId,
    required this.isCheckIn,
    this.authenticationMethod,
    this.employeeName,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final LocationStabilityService _locationStabilityService =
      LocationStabilityService();

  // متغيرات الحالة
  bool _isProcessing = false;
  bool _isInitializing = true;
  bool _usedFaceVerification = false;
  String _currentStep = '';
  Position? _currentPosition;
  Timer? _locationTimer;

  // متغيرات جديدة لتحسين إدارة الأخطاء
  final int _retryCount = 0;
  static const int _maxRetries = 3;
  String? _lastError;
  final bool _isNetworkError = false;
  final bool _isLocationError = false;
  final bool _isBiometricError = false;

  // متغيرات الرسوم المتحركة
  late AnimationController _backgroundController;
  late AnimationController _cardController;
  late AnimationController _pulseController;
  late AnimationController _successController;
  late AnimationController _errorController;

  late Animation<double> _backgroundAnimation;
  late Animation<double> _cardAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _successScaleAnimation;
  late Animation<double> _errorShakeAnimation;
  late Animation<Offset> _slideAnimation;

  // متغيرات النتيجة
  bool? _isSuccess;
  String _resultMessage = '';
  String _resultDetails = '';

  void _log(String message) {
    if (kDebugMode) {
      print('🔄 [AttendanceScreen] $message');
    }
  }

  Future<String> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform().timeout(
        const Duration(seconds: 5), // زيادة من 3 إلى 5 ثواني لتحسين الدقة
      );
      String deviceInfoString = '';
      String appVersion = 'v${packageInfo.version}+${packageInfo.buildNumber}';

      if (kIsWeb) {
        deviceInfoString = 'Web Browser | App: $appVersion';
        _log('📱 معلومات الجهاز: $deviceInfoString');
        return deviceInfoString;
      }

      if (PlatformHelper.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo.timeout(
          const Duration(seconds: 5), // زيادة من 3 إلى 5 ثواني لتحسين الدقة
        );
        deviceInfoString =
            '${androidInfo.brand} ${androidInfo.model} (Android ${androidInfo.version.release}) - ID: ${androidInfo.id} | App: $appVersion';
      } else if (PlatformHelper.isIOS) {
        final iosInfo = await deviceInfo.iosInfo.timeout(
          const Duration(seconds: 5), // زيادة من 3 إلى 5 ثواني لتحسين الدقة
        );
        deviceInfoString =
            '${iosInfo.name} ${iosInfo.model} (iOS ${iosInfo.systemVersion}) - ID: ${iosInfo.identifierForVendor} | App: $appVersion';
      } else if (PlatformHelper.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo.timeout(
          const Duration(seconds: 5), // زيادة من 3 إلى 5 ثواني لتحسين الدقة
        );
        deviceInfoString =
            'Windows ${windowsInfo.majorVersion}.${windowsInfo.minorVersion} - ID: ${windowsInfo.deviceId} | App: $appVersion';
      } else if (PlatformHelper.isMacOS) {
        final macOsInfo = await deviceInfo.macOsInfo.timeout(
          const Duration(seconds: 5), // زيادة من 3 إلى 5 ثواني لتحسين الدقة
        );
        deviceInfoString =
            'macOS ${macOsInfo.osRelease} - ID: ${macOsInfo.computerName} | App: $appVersion';
      } else if (PlatformHelper.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo.timeout(
          const Duration(seconds: 5), // زيادة من 3 إلى 5 ثواني لتحسين الدقة
        );
        deviceInfoString =
            'Linux ${linuxInfo.name} ${linuxInfo.version} - ID: ${linuxInfo.machineId} | App: $appVersion';
      } else {
        deviceInfoString = 'Unknown Device | App: $appVersion';
      }

      _log('📱 معلومات الجهاز: $deviceInfoString');
      return deviceInfoString;
    } catch (e) {
      _log('❌ خطأ في جمع معلومات الجهاز: $e');
      return 'Flutter Mobile App';
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final languageService =
          Provider.of<LanguageService>(context, listen: false);
      final lang = languageService.currentLocale.languageCode;
      setState(() {
        _currentStep = Translations.getText('preparing', lang);
      });
      _startProcess();
    });
  }

  void _initializeAnimations() {
    // تحريك الخلفية
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    _backgroundAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _backgroundController,
      curve: Curves.easeInOut,
    ));

    // تحريك البطاقة
    _cardController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _cardAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.elasticOut,
    ));

    // نبض الزر
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // نجاح العملية
    _successController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _successScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    ));

    // خطأ العملية
    _errorController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _errorShakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _errorController,
      curve: Curves.easeInOut,
    ));

    // بدء الرسوم المتحركة
    _backgroundController.forward();
    _cardController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _refreshPage() async {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;
    setState(() {
      _isProcessing = false;
      _isInitializing = true;
      _usedFaceVerification = false;
      _isSuccess = null;
      _resultMessage = '';
      _resultDetails = '';
      _currentStep = Translations.getText('preparing', lang);
    });
    _locationTimer?.cancel();
    _currentPosition = null;
    await _startProcess();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _backgroundController.dispose();
    _cardController.dispose();
    _pulseController.dispose();
    _successController.dispose();
    _errorController.dispose();
    super.dispose();
  }

  Future<void> _startProcess() async {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;

    _log('🚀 بدء عملية ${widget.isCheckIn ? 'الحضور' : 'الانصراف'}');

    // التحقق من أذونات الموقع
    await _checkLocationPermission();

    // بدء تحديثات الموقع
    _startLocationUpdates();

    // انتظار تحديد الموقع
    await _waitForLocation();

    setState(() {
      _isInitializing = false;
      _currentStep = Translations.getText('ready_to_register', lang);
    });
  }

  Future<void> _checkLocationPermission() async {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;

    setState(() {
      _currentStep =
          Translations.getText('checking_location_permissions', lang);
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError(Translations.getText('location_service_disabled', lang),
            Translations.getText('enable_location_service', lang));
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError(Translations.getText('location_permission_denied', lang),
              Translations.getText('allow_location_access', lang));
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError(
            Translations.getText('location_permission_denied_forever', lang),
            Translations.getText('enable_location_permissions', lang));
        return;
      }

      _log('✅ أذونات الموقع مفعلة بنجاح');
    } catch (e) {
      _log('❌ خطأ في التحقق من أذونات الموقع: $e');
      _showError(Translations.getText('location_permission_error', lang),
          e.toString());
    }
  }

  void _startLocationUpdates() {
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_isProcessing) {
        _updateLocation();
      }
    });
    _updateLocation();
  }

  Future<void> _updateLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit:
            const Duration(seconds: 8), // زيادة من 5 إلى 8 ثواني لتحسين الدقة
      );

      setState(() {
        _currentPosition = position;
      });

      _log('📍 تم تحديث الموقع: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      _log('❌ خطأ في تحديث الموقع: $e');
    }
  }

  Future<void> _waitForLocation() async {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;

    int attempts = 0;
    const maxAttempts = 15; // زيادة من 10 إلى 15 محاولة لتحسين الدقة

    while (_currentPosition == null && attempts < maxAttempts) {
      await Future.delayed(
          const Duration(seconds: 1)); // زيادة من 0.5 إلى 1 ثانية
      attempts++;

      if (attempts % 5 == 0) {
        setState(() {
          _currentStep =
              '${Translations.getText('determining_location', lang)}... (${Translations.getText('location_attempt', lang)} ${attempts + 1})';
        });
      }
    }

    if (_currentPosition == null) {
      _showError(Translations.getText('location_determination_failed', lang),
          Translations.getText('enable_gps_location', lang));
    }
  }

  Future<void> _processAttendance() async {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;

    if (_currentPosition == null) {
      _showError(Translations.getText('cannot_determine_location', lang),
          Translations.getText('wait_for_location', lang));
      return;
    }

    setState(() {
      _isProcessing = true;
      _currentStep = Translations.getText('checking_location', lang);
    });

    try {
      // --- إضافة التحقق من بصمة الوجه (Server-side) ---
      // يتم التحقق أولاً كما هو مطلوب في الـ Flow
      setState(() {
        _currentStep = 'جاري التحقق من إعدادات الوجه...';
      });

      final faceStatus = await FaceApiService.getFaceStatus(widget.clientId, widget.employeeNumber);
      
      if (faceStatus['Success'] != true) {
        _showError('خطأ في التحقق من الوجه', faceStatus['Message'] ?? 'لا يمكن الاتصال بسيرفر البصمة حالياً');
        setState(() {
          _isProcessing = false;
        });
        return;
      }

      final attendanceMethod =
          int.tryParse(faceStatus['AttendanceMethod']?.toString() ?? '0') ?? 0;
      final shouldRequireFace = faceStatus['IsFaceRequired'] == true ||
          attendanceMethod == 1 ||
          attendanceMethod == 2;

      if (shouldRequireFace) {
        bool faceVerified = false;

        if (faceStatus['HasFaceTemplate'] == false) {
          // الموظف يحتاج تسجيل وجهه أول مرة
          faceVerified = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FaceEnrollmentScreen(
                employeeNumber: widget.employeeNumber,
                clientId: widget.clientId,
              ),
            ),
          ) ?? false;
        } else {
          // الموظف مسجل وجهه، نحتاج نتحقق منه
          faceVerified = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FaceVerificationScreen(
                employeeNumber: widget.employeeNumber,
                clientId: widget.clientId,
                showResetButton: false,
              ),
            ),
          ) ?? false;
        }

        if (!faceVerified) {
          _showError('فشل التحقق من الوجه', 'يجب التحقق من بصمة الوجه لتسجيل الحضور');
          setState(() {
            _isProcessing = false;
          });
          return;
        }
        
        // تسجيل أنه تم استخدام بصمة الوجه بنجاح
        _usedFaceVerification = true;
      }
      // ---------------------------------------------

      // تسجيل دقة GPS للمراجعة فقط
      double accuracy = _currentPosition!.accuracy;
      _log('📍 دقة GPS الحالية: ${accuracy.toStringAsFixed(2)} متر');

      setState(() {
        _currentStep = Translations.getText('checking_developer_mode', lang);
      });

      setState(() {
        _currentStep =
            Translations.getText('checking_location_stability', lang);
      });

      // فحص ثبات الموقع
      LocationStabilityResult stabilityResult =
          await _locationStabilityService.checkLocationStabilityWithUpdates(
        initialPosition: _currentPosition!,
        updateInterval:
            const Duration(milliseconds: 1500), // ثانية ونصف بين القراءات
        requiredUpdates: 5, // زيادة إلى 5 قراءات لتحسين الدقة
        minVariationPercentage: 0.05, // تقليل من 0.1 إلى 0.05% لتحسين المرونة
      );

      if (stabilityResult.isFakeLocation == true) {
        _showError(Translations.getText('fake_location_detected', lang),
            Translations.getText('fake_location_warning', lang));
        return;
      }

      if (stabilityResult.isSuspiciouslyStable == true &&
          (_currentPosition?.accuracy ?? 999) < 25) {
        _showError(Translations.getText('suspicious_location', lang),
            Translations.getText('suspicious_location_warning', lang));
        return;
      }

      if (!stabilityResult.isStable) {
        _log(
            '⚠️ ثبات الموقع غير كافٍ، سيتم المتابعة لتفادي رفض الأجهزة الحقيقية');
      }

      setState(() {
        _currentStep = Translations.getText('checking_location_validity', lang);
      });

      // التحقق من المواقع المسموح بها
      final locationsResponse =
          await _apiService.getAttendanceLocations(widget.clientId);
      bool isLocationValid = false;

      if (locationsResponse['Success'] == true) {
        List<dynamic> locations = locationsResponse['Locations'];

        for (var location in locations) {
          try {
            double officeLat =
                double.tryParse(location['Latitude'].toString()) ?? 0.0;
            double officeLng =
                double.tryParse(location['Longitude'].toString()) ?? 0.0;
            int radiusMeters =
                int.tryParse(location['RadiusMeters'].toString()) ?? 100;

            double distance = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              officeLat,
              officeLng,
            );

            if (distance <= radiusMeters) {
              isLocationValid = true;
              break;
            }
          } catch (e) {
            continue;
          }
        }
      }

      if (!isLocationValid) {
        _showError(Translations.getText('outside_allowed_area', lang),
            Translations.getText('move_to_work_location', lang));
        return;
      }

      setState(() {
        _currentStep = Translations.getText('registering_data', lang);
      });

      setState(() {
        _currentStep = Translations.getText('checking_biometric', lang);
      });

      // التحقق من البصمة إذا كانت مطلوبة
      if (widget.authenticationMethod == 'FINGERPRINT' ||
          widget.authenticationMethod == 'FACE') {
        final biometricResult =
            await BiometricService.authenticateForAttendance(
          isCheckIn: widget.isCheckIn,
          employeeName: widget.employeeName,
        );

        if (!biometricResult) {
          _showError(
              Translations.getText('biometric_verification_failed', lang),
              'يرجى المحاولة مرة أخرى');
          return;
        }
      }

      setState(() {
        _currentStep = Translations.getText('registering_data', lang);
      });

      // جمع معلومات الجهاز
      final deviceInfo = await _getDeviceInfo();

      // إنشاء نموذج الحضور - punchTime سيتم تعيينه من السيرفر وليس من الجوال
      // هذا يضمن دقة الوقت المسجل في قاعدة البيانات ومنع التلاعب
      final attendance = AttendanceModel(
        employeeNumber: widget.employeeNumber,
        punchState: widget.isCheckIn ? "0" : "1",
        longitude: _currentPosition!.longitude,
        latitude: _currentPosition!.latitude,
        gpsLocation:
            '${_currentPosition!.latitude}, ${_currentPosition!.longitude}',
        mobile: 'Mobile App',
        notes: widget.isCheckIn ? 'Check In' : 'Check Out',
        deviceInfo: deviceInfo,
        temperature: null,
        authenticationMethod: _usedFaceVerification ? 'FACE' : (widget.authenticationMethod ?? 'GPS'),
        isLocationStable: stabilityResult.isStable,
        locationMaxVariation: stabilityResult.maxDistanceVariation,
        locationAverageDistance: stabilityResult.averageDistance,
        locationTotalReadings: stabilityResult.totalReadings,
        locationStabilityDescription:
            _locationStabilityService.getStabilityDescription(stabilityResult),
        isLocationSuspiciouslyStable: stabilityResult.isSuspiciouslyStable,
        isLocationFake: stabilityResult.isFakeLocation,
        locationAverageVariationPercentage:
            stabilityResult.averageVariationPercentage,
        locationMinVariationPercentage: stabilityResult.minVariationPercentage,
      );

      // إرسال البيانات إلى API
      Map<String, dynamic> result;
      if (widget.isCheckIn) {
        result = await _apiService.checkIn(widget.clientId, attendance);
      } else {
        result = await _apiService.checkOut(widget.clientId, attendance);
      }

      if (result['Success'] == true || result['success'] == true) {
        // تحليل رسالة النجاح من API
        String successMessage = result['Message'] ??
            result['message'] ??
            (widget.isCheckIn
                ? Translations.getText('check_in_success', lang)
                : Translations.getText('check_out_success', lang));

        Map<String, String> parsedSuccess =
            _parseApiSuccessMessage(successMessage);

        _showSuccess(parsedSuccess['title']!, parsedSuccess['details']!);
      } else {
        // تحليل رسالة الخطأ من API
        String errorMessage = result['Message'] ??
            result['message'] ??
            Translations.getText('unexpected_error', lang);

        Map<String, String> parsedError = _parseApiErrorMessage(errorMessage);

        _showError(parsedError['title']!, parsedError['details']!);
      }
    } catch (e) {
      _log('❌ خطأ في تسجيل الحضور: $e');
      _showError(Translations.getText('operation_error', lang),
          Translations.getText('contact_support', lang));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showSuccess(String message, String details) {
    setState(() {
      _isSuccess = true;
      _resultMessage = message;
      _resultDetails = details;
    });
    _successController.forward();

    // العودة للصفحة الرئيسية بعد 3 ثوانٍ
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pop(context, true);
      }
    });
  }

  void _showError(String message, String details) {
    setState(() {
      _isSuccess = false;
      _resultMessage = message;
      _resultDetails = details;
    });
    _errorController.forward();
  }

  // دالة جديدة لتحديد ما إذا كان يمكن إعادة المحاولة
  bool _canRetry(String errorMessage) {
    return errorMessage.contains('أنت خارج نطاق الموقع المعين لك') ||
        errorMessage.contains('الموقع صحيح') ||
        errorMessage.contains('خطأ في التحقق من الموقع') ||
        errorMessage.contains('خطأ في حفظ سجل الحضور') ||
        errorMessage.contains('unexpected_error') ||
        errorMessage.contains('operation_error') ||
        errorMessage.contains('error');
  }

  // دالة إعادة المحاولة
  void _retryOperation() {
    setState(() {
      _isSuccess = null;
      _resultMessage = '';
      _resultDetails = '';
    });
    _processAttendance();
  }

  // دالة جديدة لتحليل رسائل الخطأ من API
  Map<String, String> _parseApiErrorMessage(String apiMessage) {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;

    String title = '';
    String details = '';

    // تحليل الرسائل العربية أو الإنجليزية
    if (apiMessage.contains('الموظف غير معين لأي موقع') || apiMessage.toLowerCase().contains('not assigned')) {
      title = Translations.getText('employee_not_assigned', lang);
      details = Translations.getText('contact_admin_for_assignment', lang);
    } else if (apiMessage.contains('أنت خارج نطاق الموقع المعين لك') || apiMessage.toLowerCase().contains('outside')) {
      title = Translations.getText('outside_assigned_location', lang);
      // استخراج اسم الموقع المعين من الرسالة إذا كان متوفراً
      String locationName = '';
      if (apiMessage.contains('الموقع المعين:')) {
        locationName = apiMessage.split('الموقع المعين:').last.trim();
      }
      if (locationName.isNotEmpty) {
        details =
            '${Translations.getText('move_to_your_assigned_location', lang)}\n${Translations.getText('assigned_location', lang)}: $locationName';
      } else {
        details = Translations.getText('move_to_your_assigned_location', lang);
      }
    } else if (apiMessage.contains('تعيين الموظف للموقع يبدأ من')) {
      title = Translations.getText('assignment_not_started', lang);
      details = apiMessage; // عرض التاريخ من الرسالة
    } else if (apiMessage.contains('انتهت فترة تعيين الموظف للموقع')) {
      title = Translations.getText('assignment_expired', lang);
      details = apiMessage; // عرض التاريخ من الرسالة
    } else if (apiMessage.contains('الموقع المعين غير نشط')) {
      title = Translations.getText('assigned_location_inactive', lang);
      details = Translations.getText('contact_admin_activate_location', lang);
    } else if (apiMessage.contains('إحداثيات الموقع المعين غير محددة')) {
      title = Translations.getText('location_coordinates_missing', lang);
      details = Translations.getText('contact_admin_set_coordinates', lang);
    } else if (apiMessage
        .contains('لا يمكن تسجيل الانصراف بدون تسجيل الحضور')) {
      title = Translations.getText('cannot_checkout_without_checkin', lang);
      details = Translations.getText('check_in_first_then_checkout', lang);
    } else if (apiMessage.contains('لا يمكن تسجيل الحضور مرتين') || apiMessage.toLowerCase().contains('already checked in')) {
      title = Translations.getText('already_checked_in', lang);
      details = Translations.getText('cannot_check_in_twice', lang);
    } else if (apiMessage.contains('الموظف غير نشط')) {
      title = Translations.getText('employee_inactive', lang);
      details = Translations.getText('contact_admin_activate_employee', lang);
    } else if (apiMessage.contains('الموظف غير موجود')) {
      title = Translations.getText('employee_not_found', lang);
      details = Translations.getText('check_employee_number', lang);
    } else if (apiMessage.contains('إحداثيات الموقع مطلوبة')) {
      title = Translations.getText('location_coordinates_required', lang);
      details = Translations.getText('enable_gps_location', lang);
    } else if (apiMessage.contains('نوع العملية غير صحيح')) {
      title = Translations.getText('invalid_operation_type', lang);
      details = Translations.getText('use_correct_operation_type', lang);
    } else if (apiMessage.contains('رقم الموظف مطلوب')) {
      title = Translations.getText('employee_number_required', lang);
      details = Translations.getText('enter_valid_employee_number', lang);
    } else if (apiMessage.contains('بيانات الحضور مطلوبة')) {
      title = Translations.getText('attendance_data_required', lang);
      details = Translations.getText('provide_attendance_information', lang);
    } else if (apiMessage.contains('العميل غير موجود أو غير نشط')) {
      title = Translations.getText('client_not_found', lang);
      details = Translations.getText('contact_support_client_issue', lang);
    } else if (apiMessage.contains('خطأ في التحقق من الموقع')) {
      title = Translations.getText('location_verification_error', lang);
      details = Translations.getText('try_again_later', lang);
    } else if (apiMessage.contains('خطأ في حفظ سجل الحضور')) {
      title = Translations.getText('attendance_save_error', lang);
      details = Translations.getText('contact_support_database_issue', lang);
    } else {
      // الرسائل العامة
      title = Translations.getText('operation_failed', lang);
      details = apiMessage;
    }

    return {
      'title': title,
      'details': details,
    };
  }

  // دالة جديدة لتحليل رسائل النجاح من API
  Map<String, String> _parseApiSuccessMessage(String apiMessage) {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);
    final lang = languageService.currentLocale.languageCode;

    String title = '';
    String details = '';

    if (apiMessage.contains('تم تسجيل الحضور بنجاح')) {
      title = Translations.getText('check_in_success', lang);
      details =
          Translations.getText('attendance_registered_successfully', lang);
    } else if (apiMessage.contains('تم تسجيل الانصراف بنجاح')) {
      title = Translations.getText('check_out_success', lang);
      details = Translations.getText('departure_registered_successfully', lang);
    } else if (apiMessage.contains('الموقع صحيح')) {
      title = Translations.getText('location_verified', lang);
      // استخراج معلومات إضافية من الرسالة
      String additionalInfo = '';
      if (apiMessage.contains('المسافة:')) {
        additionalInfo = apiMessage.split('المسافة:').last.trim();
        if (additionalInfo.contains('متر')) {
          details =
              '${Translations.getText('location_verified_successfully', lang)}\n$additionalInfo';
        } else {
          details = apiMessage;
        }
      } else {
        details = apiMessage;
      }
    } else {
      title = Translations.getText('operation_successful', lang);
      details = apiMessage;
    }

    return {
      'title': title,
      'details': details,
    };
  }

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final lang = languageService.currentLocale.languageCode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.isCheckIn ? Colors.green.shade50 : Colors.red.shade50,
              widget.isCheckIn ? Colors.green.shade100 : Colors.red.shade100,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // شريط العنوان
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isCheckIn
                        ? [Colors.green.shade600, Colors.green.shade800]
                        : [Colors.red.shade600, Colors.red.shade800],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        widget.isCheckIn
                            ? Translations.getText(
                                'register_attendance_title', lang)
                            : Translations.getText(
                                'register_departure_title', lang),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48), // لموازنة الزر
                  ],
                ),
              ),

              // المحتوى الرئيسي
              Expanded(
                child: AnimatedBuilder(
                  animation: _backgroundAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 0.9 + (_backgroundAnimation.value * 0.1),
                      child: RefreshIndicator(
                        onRefresh: _refreshPage,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                          children: [
                            // البطاقة الرئيسية
                            AnimatedBuilder(
                              animation: _cardAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _cardAnimation.value,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(30),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.white,
                                          Colors.grey.shade50,
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 40,
                                          offset: const Offset(0, 20),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      children: [
                                        // أيقونة ثلاثية الأبعاد
                                        Container(
                                          width: 120,
                                          height: 120,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: widget.isCheckIn
                                                  ? [
                                                      Colors.green.shade400,
                                                      Colors.green.shade600
                                                    ]
                                                  : [
                                                      Colors.red.shade400,
                                                      Colors.red.shade600
                                                    ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(60),
                                            boxShadow: [
                                              BoxShadow(
                                                color: (widget.isCheckIn
                                                        ? Colors.green
                                                        : Colors.red)
                                                    .withOpacity(0.3),
                                                blurRadius: 20,
                                                offset: const Offset(0, 10),
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            widget.isCheckIn
                                                ? Icons.login
                                                : Icons.logout,
                                            size: 60,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // اسم الموظف
                                        Text(
                                          widget.employeeName ??
                                              Translations.getText(
                                                  'employee', lang),
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),

                                        // رقم الموظف
                                        Text(
                                          '${Translations.getText('employee_number_label', lang)}: ${widget.employeeNumber}',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(height: 20),

                                        // حالة العملية
                                        if (_isInitializing ||
                                            _isProcessing) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.blue.shade200,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 16,
                                                  height: 16,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(
                                                      Colors.blue.shade600,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  _currentStep,
                                                  style: TextStyle(
                                                    color: Colors.blue.shade700,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ] else if (_isSuccess != null) ...[
                                          // نتيجة العملية
                                          AnimatedBuilder(
                                            animation: _isSuccess!
                                                ? _successController
                                                : _errorController,
                                            builder: (context, child) {
                                              return Transform.scale(
                                                scale: _isSuccess!
                                                    ? _successScaleAnimation
                                                        .value
                                                    : 1.0,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(20),
                                                  decoration: BoxDecoration(
                                                    color: _isSuccess!
                                                        ? Colors.green.shade50
                                                        : Colors.red.shade50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16),
                                                    border: Border.all(
                                                      color: _isSuccess!
                                                          ? Colors
                                                              .green.shade200
                                                          : Colors.red.shade200,
                                                    ),
                                                  ),
                                                  child: Column(
                                                    children: [
                                                      Icon(
                                                        _isSuccess!
                                                            ? Icons.check_circle
                                                            : Icons.error,
                                                        size: 48,
                                                        color: _isSuccess!
                                                            ? Colors.green
                                                            : Colors.red,
                                                      ),
                                                      const SizedBox(
                                                          height: 12),
                                                      Text(
                                                        _resultMessage,
                                                        style: TextStyle(
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: _isSuccess!
                                                              ? Colors.green
                                                                  .shade700
                                                              : Colors
                                                                  .red.shade700,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        _resultDetails,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: _isSuccess!
                                                              ? Colors.green
                                                                  .shade600
                                                              : Colors
                                                                  .red.shade600,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                      ),
                                                      // زر إعادة المحاولة للرسائل التي يمكن إعادة المحاولة فيها
                                                      if (!_isSuccess! &&
                                                          _canRetry(
                                                              _resultMessage)) ...[
                                                        const SizedBox(
                                                            height: 16),
                                                        Container(
                                                          width:
                                                              double.infinity,
                                                          height: 45,
                                                          decoration:
                                                              BoxDecoration(
                                                            gradient:
                                                                LinearGradient(
                                                              colors: [
                                                                Colors.orange
                                                                    .shade400,
                                                                Colors.orange
                                                                    .shade600,
                                                              ],
                                                              begin: Alignment
                                                                  .topLeft,
                                                              end: Alignment
                                                                  .bottomRight,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        22),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .orange
                                                                    .withOpacity(
                                                                        0.3),
                                                                blurRadius: 10,
                                                                offset:
                                                                    const Offset(
                                                                        0, 4),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Material(
                                                            color: Colors
                                                                .transparent,
                                                            child: InkWell(
                                                              onTap:
                                                                  _retryOperation,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          22),
                                                              child: Center(
                                                                child: Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .refresh,
                                                                      color: Colors
                                                                          .white,
                                                                      size: 20,
                                                                    ),
                                                                    const SizedBox(
                                                                        width:
                                                                            8),
                                                                    Text(
                                                                      Translations.getText(
                                                                          'retry',
                                                                          lang),
                                                                      style:
                                                                          const TextStyle(
                                                                        color: Colors
                                                                            .white,
                                                                        fontSize:
                                                                            16,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                      // معلومات إضافية في حالة النجاح - الوقت المسجل من السيرفر
                                                      if (_isSuccess! &&
                                                          _currentPosition !=
                                                              null) ...[
                                                        const SizedBox(
                                                            height: 16),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(12),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: Colors
                                                                .green.shade50,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12),
                                                            border: Border.all(
                                                              color: Colors
                                                                  .green
                                                                  .shade200,
                                                            ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .check_circle_outline,
                                                                color: Colors
                                                                    .green
                                                                    .shade600,
                                                                size: 20,
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                              Expanded(
                                                                child: Column(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      Translations.getText(
                                                                          'registered_location',
                                                                          lang),
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                        fontWeight:
                                                                            FontWeight.bold,
                                                                        color: Colors
                                                                            .green
                                                                            .shade700,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                        height:
                                                                            4),
                                                                    Text(
                                                                      '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        color: Colors
                                                                            .green
                                                                            .shade600,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ] else ...[
                                          // زر التأكيد
                                          AnimatedBuilder(
                                            animation: _pulseAnimation,
                                            builder: (context, child) {
                                              return Transform.scale(
                                                scale: _pulseAnimation.value,
                                                child: Container(
                                                  width: double.infinity,
                                                  height: 60,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      colors: widget.isCheckIn
                                                          ? [
                                                              Colors.green
                                                                  .shade500,
                                                              Colors.green
                                                                  .shade700
                                                            ]
                                                          : [
                                                              Colors
                                                                  .red.shade500,
                                                              Colors
                                                                  .red.shade700
                                                            ],
                                                      begin: Alignment.topLeft,
                                                      end:
                                                          Alignment.bottomRight,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: (widget.isCheckIn
                                                                ? Colors.green
                                                                : Colors.red)
                                                            .withOpacity(0.3),
                                                        blurRadius: 15,
                                                        offset:
                                                            const Offset(0, 8),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      onTap: _processAttendance,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              30),
                                                      child: Center(
                                                        child: Text(
                                                          widget.isCheckIn
                                                              ? Translations
                                                                  .getText(
                                                                      'register_attendance',
                                                                      lang)
                                                              : Translations
                                                                  .getText(
                                                                      'register_departure',
                                                                      lang),
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 30),

                            // معلومات إضافية
                            if (!_isInitializing &&
                                !_isProcessing &&
                                _isSuccess == null) ...[
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          color: Colors.blue.shade600,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          Translations.getText(
                                              'important_information', lang),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      Translations.getText(
                                          'location_requirements', lang),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                        height: 1.5,
                                      ),
                                    ),
                                    // عرض معلومات الموقع الحالي
                                    if (_currentPosition != null) ...[
                                      const SizedBox(height: 16),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: Colors.green.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              color: Colors.green.shade600,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    Translations.getText(
                                                        'current_location',
                                                        lang),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color:
                                                          Colors.green.shade700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '${_currentPosition!.latitude.toStringAsFixed(6)}, ${_currentPosition!.longitude.toStringAsFixed(6)}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color:
                                                          Colors.green.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
