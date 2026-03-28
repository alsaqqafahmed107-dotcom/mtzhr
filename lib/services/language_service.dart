import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';

  Locale _currentLocale = const Locale('ar', 'SA');
  TextDirection _currentDirection = TextDirection.rtl;

  Locale get currentLocale => _currentLocale;
  TextDirection get currentDirection => _currentDirection;

  // قائمة اللغات المدعومة
  static const List<Map<String, dynamic>> supportedLanguages = [
    {
      'code': 'ar',
      'country': 'SA',
      'name': 'العربية',
      'nativeName': 'العربية',
      'direction': TextDirection.rtl,
      'flag': '🇸🇦',
    },
    {
      'code': 'en',
      'country': 'US',
      'name': 'English',
      'nativeName': 'English',
      'direction': TextDirection.ltr,
      'flag': '🇺🇸',
    },
  ];

  LanguageService() {
    _loadSavedLanguage();
  }

  // تحميل اللغة المحفوظة
  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey) ?? 'ar';
      final countryCode = prefs.getString('${_languageKey}_country') ?? 'SA';

      _setLanguage(languageCode, countryCode);
    } catch (e) {
      // في حالة الخطأ، استخدم اللغة الافتراضية
      _setLanguage('ar', 'SA');
    }
  }

  // حفظ اللغة المختارة
  Future<void> _saveLanguage(String languageCode, String countryCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      await prefs.setString('${_languageKey}_country', countryCode);
    } catch (e) {
      // تجاهل الأخطاء في الحفظ
    }
  }

  // تغيير اللغة
  Future<void> changeLanguage(String languageCode, String countryCode) async {
    await _saveLanguage(languageCode, countryCode);
    _setLanguage(languageCode, countryCode);
  }

  // تعيين اللغة
  void _setLanguage(String languageCode, String countryCode) {
    _currentLocale = Locale(languageCode, countryCode);

    // تحديد اتجاه النص
    final language = supportedLanguages.firstWhere(
      (lang) => lang['code'] == languageCode,
      orElse: () => supportedLanguages.first,
    );

    _currentDirection = language['direction'] as TextDirection;
    notifyListeners();
  }

  // الحصول على معلومات اللغة الحالية
  Map<String, dynamic> getCurrentLanguageInfo() {
    return supportedLanguages.firstWhere(
      (lang) => lang['code'] == _currentLocale.languageCode,
      orElse: () => supportedLanguages.first,
    );
  }

  // التحقق من أن اللغة هي العربية
  bool get isArabic => _currentLocale.languageCode == 'ar';

  // التحقق من أن اللغة هي الإنجليزية
  bool get isEnglish => _currentLocale.languageCode == 'en';
}
