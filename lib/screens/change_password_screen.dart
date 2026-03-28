import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/language_service.dart';
import '../services/translations.dart';
import 'package:provider/provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String email;
  final int clientId;

  const ChangePasswordScreen({
    super.key,
    required this.email,
    required this.clientId,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

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

  // متغيرات النتيجة
  bool? _isSuccess;
  String _resultMessage = '';
  String _resultDetails = '';

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _backgroundController.dispose();
    _cardController.dispose();
    _pulseController.dispose();
    _successController.dispose();
    _errorController.dispose();
    super.dispose();
  }

  void _showSuccess(String message, String details) {
    setState(() {
      _isSuccess = true;
      _resultMessage = message;
      _resultDetails = details;
    });
    _successController.forward();

    // العودة للصفحة السابقة بعد 3 ثوانٍ
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final languageService = Provider.of<LanguageService>(context);
    final isRTL = languageService.isArabic;
    final scheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withOpacity(0.10),
                scheme.secondary.withOpacity(0.10),
                scheme.surface,
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
                      colors: [scheme.primary, scheme.secondary],
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
                        icon: Icon(Icons.arrow_back_ios, color: scheme.onPrimary),
                      ),
                      Expanded(
                        child: Text(
                          Translations.getText('change_password',
                              languageService.isArabic ? 'ar' : 'en'),
                          style: TextStyle(
                            color: scheme.onPrimary,
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
                        child: SingleChildScrollView(
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
                                            color:
                                                Colors.black.withOpacity(0.1),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                          BoxShadow(
                                            color:
                                                Colors.black.withOpacity(0.05),
                                            blurRadius: 40,
                                            offset: const Offset(0, 20),
                                          ),
                                        ],
                                      ),
                                      child: Form(
                                        key: _formKey,
                                        child: Column(
                                          children: [
                                            // أيقونة ثلاثية الأبعاد
                                            Container(
                                              width: 120,
                                              height: 120,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [scheme.primary, scheme.secondary],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(60),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: scheme.primary.withOpacity(0.3),
                                                    blurRadius: 20,
                                                    offset: const Offset(0, 10),
                                                  ),
                                                ],
                                              ),
                                              child: Icon(
                                                Icons.lock_reset,
                                                size: 60,
                                                color: scheme.onPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 24),

                                            // العنوان
                                            Text(
                                              Translations.getText(
                                                  'change_password',
                                                  languageService.isArabic
                                                      ? 'ar'
                                                      : 'en'),
                                              style: const TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              Translations.getText(
                                                  'enter_current_new_password',
                                                  languageService.isArabic
                                                      ? 'ar'
                                                      : 'en'),
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: Colors.grey.shade600,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 32),

                                            // حالة العملية
                                            if (_isSuccess != null) ...[
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
                                                          const EdgeInsets.all(
                                                              20),
                                                      decoration: BoxDecoration(
                                                        color: _isSuccess!
                                                            ? Colors
                                                                .green.shade50
                                                            : Colors
                                                                .red.shade50,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                        border: Border.all(
                                                          color: _isSuccess!
                                                              ? Colors.green
                                                                  .shade200
                                                              : Colors
                                                                  .red.shade200,
                                                        ),
                                                      ),
                                                      child: Column(
                                                        children: [
                                                          Icon(
                                                            _isSuccess!
                                                                ? Icons
                                                                    .check_circle
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
                                                                  FontWeight
                                                                      .bold,
                                                              color: _isSuccess!
                                                                  ? Colors.green
                                                                      .shade700
                                                                  : Colors.red
                                                                      .shade700,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                          const SizedBox(
                                                              height: 8),
                                                          Text(
                                                            _resultDetails,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              color: _isSuccess!
                                                                  ? Colors.green
                                                                      .shade600
                                                                  : Colors.red
                                                                      .shade600,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ] else ...[
                                              // حقول كلمة المرور
                                              _buildPasswordField(
                                                controller:
                                                    _currentPasswordController,
                                                label: Translations.getText(
                                                    'current_password',
                                                    languageService.isArabic
                                                        ? 'ar'
                                                        : 'en'),
                                                hint: Translations.getText(
                                                    'enter_current_password',
                                                    languageService.isArabic
                                                        ? 'ar'
                                                        : 'en'),
                                                obscureText:
                                                    _obscureCurrentPassword,
                                                onToggleVisibility: () {
                                                  setState(() {
                                                    _obscureCurrentPassword =
                                                        !_obscureCurrentPassword;
                                                  });
                                                },
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return Translations.getText(
                                                        'current_password_required',
                                                        languageService.isArabic
                                                            ? 'ar'
                                                            : 'en');
                                                  }
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 20),

                                              _buildPasswordField(
                                                controller:
                                                    _newPasswordController,
                                                label: Translations.getText(
                                                    'new_password',
                                                    languageService.isArabic
                                                        ? 'ar'
                                                        : 'en'),
                                                hint: Translations.getText(
                                                    'enter_new_password',
                                                    languageService.isArabic
                                                        ? 'ar'
                                                        : 'en'),
                                                obscureText:
                                                    _obscureNewPassword,
                                                onToggleVisibility: () {
                                                  setState(() {
                                                    _obscureNewPassword =
                                                        !_obscureNewPassword;
                                                  });
                                                },
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return Translations.getText(
                                                        'new_password_required',
                                                        languageService.isArabic
                                                            ? 'ar'
                                                            : 'en');
                                                  }
                                                  if (value.length < 6) {
                                                    return Translations.getText(
                                                        'password_min_length',
                                                        languageService.isArabic
                                                            ? 'ar'
                                                            : 'en');
                                                  }
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 20),

                                              _buildPasswordField(
                                                controller:
                                                    _confirmPasswordController,
                                                label: Translations.getText(
                                                    'confirm_new_password',
                                                    languageService.isArabic
                                                        ? 'ar'
                                                        : 'en'),
                                                hint: Translations.getText(
                                                    're_enter_new_password',
                                                    languageService.isArabic
                                                        ? 'ar'
                                                        : 'en'),
                                                obscureText:
                                                    _obscureConfirmPassword,
                                                onToggleVisibility: () {
                                                  setState(() {
                                                    _obscureConfirmPassword =
                                                        !_obscureConfirmPassword;
                                                  });
                                                },
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return Translations.getText(
                                                        'confirm_password_required',
                                                        languageService.isArabic
                                                            ? 'ar'
                                                            : 'en');
                                                  }
                                                  if (value !=
                                                      _newPasswordController
                                                          .text) {
                                                    return Translations.getText(
                                                        'passwords_not_match',
                                                        languageService.isArabic
                                                            ? 'ar'
                                                            : 'en');
                                                  }
                                                  return null;
                                                },
                                              ),
                                              const SizedBox(height: 32),

                                              // زر التأكيد
                                              AnimatedBuilder(
                                                animation: _pulseAnimation,
                                                builder: (context, child) {
                                                  return Transform.scale(
                                                    scale:
                                                        _pulseAnimation.value,
                                                    child: Container(
                                                      width: double.infinity,
                                                      height: 60,
                                                      decoration: BoxDecoration(
                                                        gradient: LinearGradient(
                                                          colors: [scheme.primary, scheme.secondary],
                                                          begin: Alignment.topLeft,
                                                          end: Alignment.bottomRight,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(30),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: scheme.primary.withOpacity(0.3),
                                                            blurRadius: 15,
                                                            offset:
                                                                const Offset(
                                                                    0, 8),
                                                          ),
                                                        ],
                                                      ),
                                                      child: Material(
                                                        color:
                                                            Colors.transparent,
                                                        child: InkWell(
                                                          onTap: _isLoading
                                                              ? null
                                                              : _handleChangePassword,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(30),
                                                          child: Center(
                                                            child: _isLoading
                                                                ? const SizedBox(
                                                                    height: 20,
                                                                    width: 20,
                                                                    child:
                                                                        CircularProgressIndicator(strokeWidth: 2),
                                                                  )
                                                                : Text(
                                                                    Translations.getText(
                                                                        'change_password',
                                                                        languageService.isArabic
                                                                            ? 'ar'
                                                                            : 'en'),
                                                                    style: TextStyle(
                                                                      color: scheme.onPrimary,
                                                                      fontSize: 18,
                                                                      fontWeight: FontWeight.bold,
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
                                    ),
                                  );
                                },
                              ),

                              const SizedBox(height: 30),

                              // معلومات إضافية
                              if (_isSuccess == null) ...[
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
                                            color: scheme.primary,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            Translations.getText(
                                                'info',
                                                languageService.isArabic
                                                    ? 'ar'
                                                    : 'en'),
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: scheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        Translations.getText('password_tips', languageService.isArabic ? 'ar' : 'en'),
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade600,
                                          height: 1.5,
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
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide:
                    const BorderSide(color: Color(0xFF0EA5E9), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey.shade600,
                ),
                onPressed: onToggleVisibility,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Future<void> _handleChangePassword() async {
    final languageService =
        Provider.of<LanguageService>(context, listen: false);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService().changePassword(
        clientId: widget.clientId,
        email: widget.email,
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
        confirmPassword: _confirmPasswordController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (response['success'] == true) {
          _showSuccess(
            Translations.getText('password_changed_successfully',
                languageService.isArabic ? 'ar' : 'en'),
            Translations.getText(
                'success', languageService.isArabic ? 'ar' : 'en'),
          );
        } else {
          _showError(
            Translations.getText('password_change_error',
                languageService.isArabic ? 'ar' : 'en'),
            response['message'] ??
                Translations.getText(
                    'error', languageService.isArabic ? 'ar' : 'en'),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        _showError(
          Translations.getText(
              'error_occurred', languageService.isArabic ? 'ar' : 'en'),
          e.toString(),
        );
      }
    }
  }
}
