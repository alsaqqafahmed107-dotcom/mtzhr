@echo off
chcp 65001 >nul
echo 🚀 بدء تهيئة التطبيق لـ iOS...

REM التحقق من وجود Flutter
flutter --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Flutter غير مثبت. يرجى تثبيت Flutter أولاً.
    pause
    exit /b 1
)

echo ✅ التحقق من التبعيات مكتمل

REM تنظيف المشروع
echo 🧹 تنظيف المشروع...
cd ..
flutter clean
flutter pub get

REM الانتقال إلى مجلد iOS
cd ios

REM حذف الملفات القديمة
echo 🗑️ حذف الملفات القديمة...
if exist Pods rmdir /s /q Pods
if exist .symlinks rmdir /s /q .symlinks
if exist Flutter\Flutter.framework rmdir /s /q Flutter\Flutter.framework
if exist Flutter\Flutter.podspec del /q Flutter\Flutter.podspec
if exist Flutter\Generated.xcconfig del /q Flutter\Generated.xcconfig
if exist Podfile.lock del /q Podfile.lock

REM تثبيت CocoaPods
echo 📦 تثبيت CocoaPods...
pod install

if errorlevel 1 (
    echo ❌ فشل في تثبيت CocoaPods
    echo يرجى التأكد من تثبيت CocoaPods: sudo gem install cocoapods
    pause
    exit /b 1
)

echo ✅ تم تثبيت CocoaPods بنجاح

REM بناء المشروع للتأكد من عدم وجود أخطاء
echo 🔨 بناء المشروع...
cd ..
flutter build ios --no-codesign

if errorlevel 1 (
    echo ❌ فشل في بناء المشروع
    pause
    exit /b 1
)

echo ✅ تم بناء المشروع بنجاح

echo.
echo 🎉 تم تهيئة التطبيق لـ iOS بنجاح!
echo.
echo 📋 الخطوات التالية:
echo 1. افتح Xcode: open ios/Runner.xcworkspace
echo 2. اختر جهاز أو محاكي
echo 3. اضغط على زر التشغيل
echo.
echo 🔧 إذا واجهت أي مشاكل:
echo - تأكد من أن Xcode محدث
echo - تأكد من أن شهادة التطوير صحيحة
echo - تأكد من أن Bundle Identifier فريد
echo.
echo 📚 للمزيد من المعلومات، راجع ملف README.md في مجلد ios
pause 