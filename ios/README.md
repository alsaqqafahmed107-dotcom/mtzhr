# تهيئة التطبيق لـ iOS

## المتطلبات الأساسية

- Xcode 14.0 أو أحدث
- iOS 12.0 أو أحدث
- CocoaPods
- Flutter SDK

## خطوات التهيئة

### 1. تثبيت CocoaPods
```bash
sudo gem install cocoapods
```

### 2. تنظيف المشروع
```bash
cd ios
rm -rf Pods
rm -rf .symlinks
rm -rf Flutter/Flutter.framework
rm -rf Flutter/Flutter.podspec
rm -rf Flutter/Generated.xcconfig
rm Podfile.lock
```

### 3. تثبيت التبعيات
```bash
flutter clean
flutter pub get
cd ios
pod install
```

### 4. فتح المشروع في Xcode
```bash
open Runner.xcworkspace
```

## إعدادات Xcode

### 1. إعدادات المشروع
- افتح `Runner.xcworkspace` في Xcode
- اختر مشروع `Runner`
- في تبويب `General`:
  - تأكد من أن `Deployment Target` هو `12.0`
  - تأكد من أن `Bundle Identifier` صحيح
  - تأكد من أن `Version` و `Build` صحيحان

### 2. إعدادات التوقيع
- في تبويب `Signing & Capabilities`:
  - اختر `Automatically manage signing`
  - اختر `Team` الخاص بك
  - تأكد من أن `Bundle Identifier` فريد

### 3. إعدادات الأذونات
تم إضافة جميع الأذونات المطلوبة في `Info.plist`:
- الموقع
- الكاميرا
- الصور
- الميكروفون
- Face ID / Touch ID
- الإشعارات

## الميزات المدعومة

### 1. المصادقة البيومترية
- Face ID للأجهزة المدعومة
- Touch ID للأجهزة المدعومة

### 2. خدمات الموقع
- تتبع الموقع في الخلفية
- دقة عالية للموقع
- حفظ بيانات الموقع

### 3. الإشعارات
- إشعارات محلية
- إشعارات عن بُعد (إذا تم إعداد Firebase)
- إشعارات في الخلفية

### 4. الخدمات الخلفية
- تحديث البيانات في الخلفية
- معالجة المهام في الخلفية
- حفظ البيانات المحلية

## استكشاف الأخطاء

### مشاكل شائعة:

1. **خطأ في CocoaPods**
   ```bash
   cd ios
   pod deintegrate
   pod install
   ```

2. **خطأ في التوقيع**
   - تأكد من أن شهادة التطوير صحيحة
   - تأكد من أن Bundle Identifier فريد

3. **خطأ في الأذونات**
   - تأكد من أن جميع الأذونات مضافة في Info.plist
   - تأكد من أن النصوص التوضيحية واضحة

4. **خطأ في البناء**
   ```bash
   flutter clean
   flutter pub get
   cd ios
   pod install
   flutter build ios
   ```

## اختبار التطبيق

### على المحاكي
```bash
flutter run
```

### على الجهاز الفعلي
1. اربط iPhone بالكمبيوتر
2. اختر الجهاز في Xcode
3. اضغط على زر التشغيل

## نشر التطبيق

### 1. إعداد الإنتاج
```bash
flutter build ios --release
```

### 2. رفع التطبيق
- استخدم Xcode لرفع التطبيق إلى App Store Connect
- أو استخدم `fastlane` للأتمتة

## ملاحظات مهمة

- تأكد من اختبار التطبيق على أجهزة مختلفة
- تأكد من اختبار جميع الميزات
- تأكد من أن الأداء جيد
- تأكد من أن التطبيق يتبع إرشادات App Store 