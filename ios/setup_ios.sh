#!/bin/bash

echo "🚀 بدء تهيئة التطبيق لـ iOS..."

# التحقق من وجود Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter غير مثبت. يرجى تثبيت Flutter أولاً."
    exit 1
fi

# التحقق من وجود CocoaPods
if ! command -v pod &> /dev/null; then
    echo "❌ CocoaPods غير مثبت. يرجى تثبيت CocoaPods أولاً."
    echo "sudo gem install cocoapods"
    exit 1
fi

echo "✅ التحقق من التبعيات مكتمل"

# تنظيف المشروع
echo "🧹 تنظيف المشروع..."
cd ..
flutter clean
flutter pub get

# الانتقال إلى مجلد iOS
cd ios

# حذف الملفات القديمة
echo "🗑️ حذف الملفات القديمة..."
rm -rf Pods
rm -rf .symlinks
rm -rf Flutter/Flutter.framework
rm -rf Flutter/Flutter.podspec
rm -rf Flutter/Generated.xcconfig
rm -f Podfile.lock

# تثبيت CocoaPods
echo "📦 تثبيت CocoaPods..."
pod install

if [ $? -eq 0 ]; then
    echo "✅ تم تثبيت CocoaPods بنجاح"
else
    echo "❌ فشل في تثبيت CocoaPods"
    exit 1
fi

# بناء المشروع للتأكد من عدم وجود أخطاء
echo "🔨 بناء المشروع..."
cd ..
flutter build ios --no-codesign

if [ $? -eq 0 ]; then
    echo "✅ تم بناء المشروع بنجاح"
else
    echo "❌ فشل في بناء المشروع"
    exit 1
fi

echo ""
echo "🎉 تم تهيئة التطبيق لـ iOS بنجاح!"
echo ""
echo "📋 الخطوات التالية:"
echo "1. افتح Xcode: open ios/Runner.xcworkspace"
echo "2. اختر جهاز أو محاكي"
echo "3. اضغط على زر التشغيل"
echo ""
echo "🔧 إذا واجهت أي مشاكل:"
echo "- تأكد من أن Xcode محدث"
echo "- تأكد من أن شهادة التطوير صحيحة"
echo "- تأكد من أن Bundle Identifier فريد"
echo ""
echo "📚 للمزيد من المعلومات، راجع ملف README.md في مجلد ios" 