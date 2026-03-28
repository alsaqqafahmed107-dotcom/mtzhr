import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class PermissionService {
  // طلب أذونات التخزين
  static Future<bool> requestStoragePermission(BuildContext context) async {
    try {
      // طلب إذن التخزين
      final storageStatus = await Permission.storage.request();

      if (storageStatus.isGranted) {
        return true;
      }

      // إذا لم يتم منح الإذن، طلب إدارة التخزين
      if (storageStatus.isDenied) {
        final manageStorageStatus =
            await Permission.manageExternalStorage.request();
        if (manageStorageStatus.isGranted) {
          return true;
        }
      }

      // إذا لم يتم منح الإذن، عرض رسالة للمستخدم
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('إذن مطلوب'),
              content: const Text(
                'يحتاج التطبيق إلى إذن للوصول إلى الملفات لتحميل المرفقات. '
                'يرجى منح الإذن من إعدادات التطبيق.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    openAppSettings();
                  },
                  child: const Text('إعدادات التطبيق'),
                ),
              ],
            );
          },
        );
      }

      return false;
    } catch (e) {
      print('خطأ في طلب إذن التخزين: $e');
      return false;
    }
  }

  // طلب أذونات الملفات (Android 13+)
  static Future<bool> requestMediaPermissions(BuildContext context) async {
    try {
      // طلب أذونات الوسائط المختلفة
      final imageStatus = await Permission.photos.request();
      final videoStatus = await Permission.videos.request();
      final audioStatus = await Permission.audio.request();

      // التحقق من جميع الأذونات
      if (imageStatus.isGranted &&
          videoStatus.isGranted &&
          audioStatus.isGranted) {
        return true;
      }

      // إذا لم يتم منح الأذونات، عرض رسالة للمستخدم
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('أذونات مطلوبة'),
              content: const Text(
                'يحتاج التطبيق إلى أذونات للوصول إلى الصور والفيديوهات والملفات الصوتية. '
                'يرجى منح الأذونات المطلوبة.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    openAppSettings();
                  },
                  child: const Text('إعدادات التطبيق'),
                ),
              ],
            );
          },
        );
      }

      return false;
    } catch (e) {
      print('خطأ في طلب أذونات الوسائط: $e');
      return false;
    }
  }

  // التحقق من أذونات التخزين
  static Future<bool> checkStoragePermission() async {
    try {
      final storageStatus = await Permission.storage.status;
      final manageStorageStatus = await Permission.manageExternalStorage.status;

      return storageStatus.isGranted || manageStorageStatus.isGranted;
    } catch (e) {
      print('خطأ في التحقق من إذن التخزين: $e');
      return false;
    }
  }

  // التحقق من أذونات الوسائط
  static Future<bool> checkMediaPermissions() async {
    try {
      final imageStatus = await Permission.photos.status;
      final videoStatus = await Permission.videos.status;
      final audioStatus = await Permission.audio.status;

      return imageStatus.isGranted &&
          videoStatus.isGranted &&
          audioStatus.isGranted;
    } catch (e) {
      print('خطأ في التحقق من أذونات الوسائط: $e');
      return false;
    }
  }

  // طلب جميع الأذونات المطلوبة
  static Future<bool> requestAllPermissions(BuildContext context) async {
    try {
      // طلب أذونات التخزين
      final storageGranted = await requestStoragePermission(context);

      // طلب أذونات الوسائط
      final mediaGranted = await requestMediaPermissions(context);

      return storageGranted && mediaGranted;
    } catch (e) {
      print('خطأ في طلب الأذونات: $e');
      return false;
    }
  }

  // عرض رسالة خطأ للأذونات
  static void showPermissionError(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('خطأ في الأذونات'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('إعدادات التطبيق'),
            ),
          ],
        );
      },
    );
  }

  // فتح إعدادات التطبيق
  static Future<void> openAppSettings() async {
    try {
      await openAppSettings();
    } catch (e) {
      print('خطأ في فتح إعدادات التطبيق: $e');
    }
  }
}
