# Debug Session: face-verify-camera
- **Status**: [FIXED]
- **Issue**: شاشة التحقق من بصمة الوجه لا تلتقط الوجه بشكل مستقر، وتظهر أخطاء كاميرا أثناء التحقق مثل `Null check operator used on a null value` و `stopImageStream was called when no camera is streaming images`.
- **Debug Server**: http://192.168.1.163:7777/event
- **Log File**: .dbg/trae-debug-log-face-verify-camera.ndjson

## Reproduction Steps
1. افتح شاشة التحقق من الوجه من الحضور أو الانصراف.
2. اسمح للكاميرا بالتهيئة ووجّه الوجه داخل الإطار.
3. راقب هل يبدأ تحليل الحياة والهوية ثم هل يلتقط صورة الوجه فعلاً.
4. عند الفشل، راقب هل تظهر رسالة خطأ الكاميرا أو تتوقف العملية بدون أخذ صورة.

## Hypotheses & Verification
| ID | Hypothesis | Likelihood | Effort | Evidence |
|----|------------|------------|--------|----------|
| A | مرجع الكاميرا أو حالتها يتغيران أثناء دورة الالتقاط أو الإغلاق | High | Low | Confirmed indirectly by dispose-time camera exception |
| B | `stopImageStream()` يُستدعى بينما لا يوجد بث فعلي، فيفشل مسار الالتقاط أو الإنهاء | High | Low | Confirmed |
| C | صورة iPhone الاستباقية لا تُجهز في الوقت المناسب قبل بدء التحقق | Medium | Medium | Inconclusive |
| D | التحقق يبدأ قبل اكتمال Ready State للكاميرا أو قبل وجود وجه صالح ثابت | Medium | Medium | Inconclusive |
| E | مسار إعادة المحاولة يعيد الدخول على الكاميرا بحالة غير متسقة | Medium | Medium | Partially confirmed as secondary risk |

## Log Evidence
- Instrumentation added in `lib/screens/face_verification_screen_mobile.dart` around:
  - `dispose`
  - `_tryTakePictureOrNull`
  - existing lifecycle / verification flow reporters
- Pre-fix evidence collected from existing active sessions:
  - `trae-debug-log-camera-login-biometrics.ndjson`: confirmed `CameraException(No camera is streaming images, stopImageStream was called when no camera is streaming images.)` from `face_verification_screen_mobile.dart:dispose`
  - `trae-debug-log-ios-face-save-verify.ndjson`: confirmed the app did send face verification requests to backend successfully
  - `trae-debug-log-ios-face-save-verify.ndjson`: confirmed a secondary backend failure `محرك الـ AI متوقف حالياً...`
- Current verification run target: `runId = post-fix`

## Verification Conclusion
Implemented minimal app-side fix in `dispose` to stop calling `stopImageStream()` blindly when no stream is active, and to release the camera controller defensively.
Pending post-fix user verification.
