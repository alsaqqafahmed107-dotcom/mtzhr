import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'services/notification_service.dart';
import 'services/language_service.dart';
import 'config/api_config.dart';
import 'theme/app_theme.dart';
import 'models/api_models.dart' as api_models;
import 'screens/home_screen.dart';
import 'package:url_strategy/url_strategy.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تهيئة خدمة الإشعارات
  await NotificationService().initialize();

  // تحسين تجربة الويب: إزالة # من الروابط
  if (kIsWeb) {
    setPathUrlStrategy();
  }

  // تهيئة ApiConfig وجلب الرابط المحول
  await ApiConfig.initialize();

  // التحقق من وجود جلسة مسجلة مسبقاً (Remember Me)
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('is_logged_in') ?? false;
  final String? userDataJson = prefs.getString('user_data');
  
  api_models.EmployeeData? savedUser;
  if (isLoggedIn && userDataJson != null) {
    try {
      final Map<String, dynamic> userMap = json.decode(userDataJson);
      savedUser = api_models.EmployeeData.fromJson(userMap);
    } catch (e) {
      if (kDebugMode) print('❌ خطأ في تحميل بيانات المستخدم المحفوظة: $e');
    }
  }

  runApp(MyApp(savedUser: savedUser));
}

class MyApp extends StatelessWidget {
  final api_models.EmployeeData? savedUser;
  
  const MyApp({super.key, this.savedUser});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LanguageService(),
      child: Consumer<LanguageService>(
        builder: (context, languageService, child) {
          return MaterialApp(
            title: 'Smart Vision',
            debugShowCheckedModeBanner: false,

            // دعم اللغات المحلية
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ar', 'SA'), // العربية - السعودية
              Locale('en', 'US'), // الإنجليزية - الولايات المتحدة
            ],
            locale: languageService.currentLocale,

            // دعم الاتجاه من اليمين إلى اليسار
            builder: (context, child) {
              return Directionality(
                textDirection: languageService.currentDirection,
                child: child!,
              );
            },

            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,

            home: savedUser != null
                ? HomeScreen(
                    employeeId: savedUser!.employeeNumber,
                    employeeData: savedUser!,
                  )
                : const LoginScreen(),
          );
        },
      ),
    );
  }
}
