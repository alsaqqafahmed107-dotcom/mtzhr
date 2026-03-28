import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // دالة تسجيل الأحداث للتطوير
  void _log(String message) {
    if (kDebugMode) {
      print('🔔 [NotificationService] $message');
    }
  }

  /// تهيئة خدمة الإشعارات
  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      _log('🔄 جاري تهيئة خدمة الإشعارات...');

      // إعدادات Android
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // إعدادات iOS
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // إعدادات التهيئة العامة
      const InitializationSettings initializationSettings =
          InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      // تهيئة الإشعارات
      await _notifications.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      _log('✅ تم تهيئة خدمة الإشعارات بنجاح');
    } catch (e) {
      _log('❌ خطأ في تهيئة خدمة الإشعارات: $e');
    }
  }

  /// معالج النقر على الإشعار
  void _onNotificationTapped(NotificationResponse response) {
    _log('👆 تم النقر على الإشعار: ${response.payload}');
    // يمكن إضافة منطق إضافي هنا للتعامل مع النقر على الإشعار
  }

  /// إرسال إشعار نجاح تسجيل الحضور
  Future<void> showCheckInSuccessNotification({
    required String employeeName,
    required String time,
    required String location,
  }) async {
    if (kIsWeb) return;
    try {
      _log('🔔 إرسال إشعار نجاح تسجيل الحضور');

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'attendance_channel',
        'إشعارات الحضور والانصراف',
        channelDescription: 'إشعارات خاصة بتسجيل الحضور والانصراف',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        color: Color(0xFF0EA5E9),
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _notifications.show(
        1, // معرف فريد للإشعار
        '✅ تم تسجيل الحضور بنجاح',
        'تم تسجيل حضور $employeeName في الساعة $time\nالموقع: $location',
        platformChannelSpecifics,
        payload: 'checkin_success',
      );

      _log('✅ تم إرسال إشعار نجاح تسجيل الحضور');
    } catch (e) {
      _log('❌ خطأ في إرسال إشعار نجاح تسجيل الحضور: $e');
    }
  }

  /// إرسال إشعار نجاح تسجيل الإنصراف
  Future<void> showCheckOutSuccessNotification({
    required String employeeName,
    required String time,
    required String location,
  }) async {
    if (kIsWeb) return;
    try {
      _log('🔔 إرسال إشعار نجاح تسجيل الإنصراف');

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'attendance_channel',
        'إشعارات الحضور والانصراف',
        channelDescription: 'إشعارات خاصة بتسجيل الحضور والانصراف',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        color: Color(0xFF0EA5E9),
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _notifications.show(
        2, // معرف فريد للإشعار
        '✅ تم تسجيل الإنصراف بنجاح',
        'تم تسجيل انصراف $employeeName في الساعة $time\nالموقع: $location',
        platformChannelSpecifics,
        payload: 'checkout_success',
      );

      _log('✅ تم إرسال إشعار نجاح تسجيل الإنصراف');
    } catch (e) {
      _log('❌ خطأ في إرسال إشعار نجاح تسجيل الإنصراف: $e');
    }
  }

  /// إرسال إشعار خطأ
  Future<void> showErrorNotification({
    required String title,
    required String message,
  }) async {
    if (kIsWeb) return;
    try {
      _log('🔔 إرسال إشعار خطأ');

      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'attendance_channel',
        'إشعارات الحضور والانصراف',
        channelDescription: 'إشعارات خاصة بتسجيل الحضور والانصراف',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        enableLights: true,
        color: Color(0xFFEF4444),
        icon: '@mipmap/ic_launcher',
        largeIcon: DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: BigTextStyleInformation(''),
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
          DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
      );

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _notifications.show(
        3, // معرف فريد للإشعار
        title,
        message,
        platformChannelSpecifics,
        payload: 'error',
      );

      _log('✅ تم إرسال إشعار الخطأ');
    } catch (e) {
      _log('❌ خطأ في إرسال إشعار الخطأ: $e');
    }
  }

  /// إلغاء جميع الإشعارات
  Future<void> cancelAllNotifications() async {
    if (kIsWeb) return;
    try {
      await _notifications.cancelAll();
      _log('✅ تم إلغاء جميع الإشعارات');
    } catch (e) {
      _log('❌ خطأ في إلغاء الإشعارات: $e');
    }
  }

  /// إلغاء إشعار محدد
  Future<void> cancelNotification(int id) async {
    try {
      await _notifications.cancel(id);
      _log('✅ تم إلغاء الإشعار رقم $id');
    } catch (e) {
      _log('❌ خطأ في إلغاء الإشعار: $e');
    }
  }
}
