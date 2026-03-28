import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

// دالة تسجيل الأحداث للتطوير
void _log(String message) {
  if (kDebugMode) {
    print(message);
  }
}

void main() async {
  _log('🧪 بدء اختبار الأذونات...');

  // اختبار أذونات التخزين
  _log('\n📁 اختبار أذونات التخزين...');

  final storageStatus = await Permission.storage.status;
  _log('📋 حالة إذن التخزين: $storageStatus');

  final manageStorageStatus = await Permission.manageExternalStorage.status;
  _log('📋 حالة إدارة التخزين: $manageStorageStatus');

  // اختبار أذونات الوسائط
  _log('\n📸 اختبار أذونات الوسائط...');

  final photosStatus = await Permission.photos.status;
  _log('📋 حالة أذونات الصور: $photosStatus');

  final videosStatus = await Permission.videos.status;
  _log('📋 حالة أذونات الفيديو: $videosStatus');

  final audioStatus = await Permission.audio.status;
  _log('📋 حالة أذونات الصوت: $audioStatus');

  // طلب الأذونات
  _log('\n🔐 طلب الأذونات...');

  if (storageStatus.isDenied) {
    _log('📝 طلب إذن التخزين...');
    final storageResult = await Permission.storage.request();
    _log('📋 نتيجة طلب إذن التخزين: $storageResult');
  }

  if (manageStorageStatus.isDenied) {
    _log('📝 طلب إدارة التخزين...');
    final manageResult = await Permission.manageExternalStorage.request();
    _log('📋 نتيجة طلب إدارة التخزين: $manageResult');
  }

  if (photosStatus.isDenied) {
    _log('📝 طلب أذونات الصور...');
    final photosResult = await Permission.photos.request();
    _log('📋 نتيجة طلب أذونات الصور: $photosResult');
  }

  if (videosStatus.isDenied) {
    _log('📝 طلب أذونات الفيديو...');
    final videosResult = await Permission.videos.request();
    _log('📋 نتيجة طلب أذونات الفيديو: $videosResult');
  }

  if (audioStatus.isDenied) {
    _log('📝 طلب أذونات الصوت...');
    final audioResult = await Permission.audio.request();
    _log('📋 نتيجة طلب أذونات الصوت: $audioResult');
  }

  // التحقق النهائي
  _log('\n✅ التحقق النهائي من الأذونات...');

  final finalStorageStatus = await Permission.storage.status;
  final finalManageStorageStatus =
      await Permission.manageExternalStorage.status;
  final finalPhotosStatus = await Permission.photos.status;
  final finalVideosStatus = await Permission.videos.status;
  final finalAudioStatus = await Permission.audio.status;

  _log(
      '📋 إذن التخزين: ${finalStorageStatus.isGranted ? "✅ ممنوح" : "❌ مرفوض"}');
  _log(
      '📋 إدارة التخزين: ${finalManageStorageStatus.isGranted ? "✅ ممنوح" : "❌ مرفوض"}');
  _log(
      '📋 أذونات الصور: ${finalPhotosStatus.isGranted ? "✅ ممنوح" : "❌ مرفوض"}');
  _log(
      '📋 أذونات الفيديو: ${finalVideosStatus.isGranted ? "✅ ممنوح" : "❌ مرفوض"}');
  _log(
      '📋 أذونات الصوت: ${finalAudioStatus.isGranted ? "✅ ممنوح" : "❌ مرفوض"}');

  // تقرير شامل
  _log('\n📊 تقرير شامل:');

  final hasStoragePermission =
      finalStorageStatus.isGranted || finalManageStorageStatus.isGranted;
  final hasMediaPermissions = finalPhotosStatus.isGranted &&
      finalVideosStatus.isGranted &&
      finalAudioStatus.isGranted;

  _log(
      '📁 أذونات التخزين: ${hasStoragePermission ? "✅ متوفرة" : "❌ غير متوفرة"}');
  _log(
      '📸 أذونات الوسائط: ${hasMediaPermissions ? "✅ متوفرة" : "❌ غير متوفرة"}');

  if (hasStoragePermission && hasMediaPermissions) {
    _log('🎉 جميع الأذونات متوفرة! يمكن استخدام المرفقات.');
  } else {
    _log('⚠️ بعض الأذونات غير متوفرة. قد تواجه مشاكل في استخدام المرفقات.');

    if (!hasStoragePermission) {
      _log('💡 الحل: منح أذونات التخزين من إعدادات التطبيق');
    }

    if (!hasMediaPermissions) {
      _log('💡 الحل: منح أذونات الوسائط من إعدادات التطبيق');
    }
  }

  _log('\n🏁 انتهى اختبار الأذونات');
}
