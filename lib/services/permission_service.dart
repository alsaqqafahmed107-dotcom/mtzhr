import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:provider/provider.dart';
import 'language_service.dart';
import 'translations.dart';

class PermissionService {
  // طلب أذونات التخزين
  static Future<bool> requestStoragePermission(BuildContext context) async {
    try {
      // طلب إذن التخزين
      final storageStatus = await ph.Permission.storage.request();

      if (storageStatus.isGranted) {
        return true;
      }

      // إذا لم يتم منح الإذن، طلب إدارة التخزين
      if (storageStatus.isDenied) {
        final manageStorageStatus =
            await ph.Permission.manageExternalStorage.request();
        if (manageStorageStatus.isGranted) {
          return true;
        }
      }

      // إذا لم يتم منح الإذن، عرض رسالة للمستخدم
      if (context.mounted) {
        final lang = Provider.of<LanguageService>(context, listen: false)
            .currentLocale
            .languageCode;
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(Translations.getText('permission_required_title', lang)),
              content: Text(
                Translations.getText('permission_storage_content', lang),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(Translations.getText('cancel', lang)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ph.openAppSettings();
                  },
                  child: Text(Translations.getText('app_settings', lang)),
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
      final imageStatus = await ph.Permission.photos.request();
      final videoStatus = await ph.Permission.videos.request();
      final audioStatus = await ph.Permission.audio.request();

      // التحقق من جميع الأذونات
      if (imageStatus.isGranted &&
          videoStatus.isGranted &&
          audioStatus.isGranted) {
        return true;
      }

      // إذا لم يتم منح الأذونات، عرض رسالة للمستخدم
      if (context.mounted) {
        final lang = Provider.of<LanguageService>(context, listen: false)
            .currentLocale
            .languageCode;
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(Translations.getText('permissions_required_title', lang)),
              content: Text(
                Translations.getText('media_permissions_content', lang),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(Translations.getText('cancel', lang)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ph.openAppSettings();
                  },
                  child: Text(Translations.getText('app_settings', lang)),
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
      final storageStatus = await ph.Permission.storage.status;
      final manageStorageStatus = await ph.Permission.manageExternalStorage.status;

      return storageStatus.isGranted || manageStorageStatus.isGranted;
    } catch (e) {
      print('خطأ في التحقق من إذن التخزين: $e');
      return false;
    }
  }

  // التحقق من أذونات الوسائط
  static Future<bool> checkMediaPermissions() async {
    try {
      final imageStatus = await ph.Permission.photos.status;
      final videoStatus = await ph.Permission.videos.status;
      final audioStatus = await ph.Permission.audio.status;

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
    final lang = Provider.of<LanguageService>(context, listen: false)
        .currentLocale
        .languageCode;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(Translations.getText('permission_error_title', lang)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(Translations.getText('cancel', lang)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                ph.openAppSettings();
              },
              child: Text(Translations.getText('app_settings', lang)),
            ),
          ],
        );
      },
    );
  }
}
