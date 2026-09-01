# Debug Session: ios-face-save-verify
- **Status**: [OPEN]
- **Issue**: على iPhone تعرض شاشة تسجيل الوجه نجاحًا أو تتقدم في التدفق، لكن الصورة لا تُحفظ فعليًا أو يتم التقاط أكثر من صورة، ثم تفشل شاشة التحقق اللاحقة في مطابقة الوجه.
- **Debug Server**: pending
- **Log File**: .dbg/trae-debug-log-ios-face-save-verify.ndjson

## Reproduction Steps
1. فتح شاشة تسجيل الوجه على iPhone.
2. الوقوف داخل الإطار حتى تظهر رسالة الجاهزية أو بدء الالتقاط.
3. ملاحظة هل تظهر رسالة نجاح الحفظ أو الانتقال للشاشة التالية.
4. تجربة التحقق مباشرة بعد التسجيل.

## Hypotheses & Verification
| ID | Hypothesis | Likelihood | Effort | Evidence |
|----|------------|------------|--------|----------|
| A | واجهة Flutter تعتبر الحفظ ناجحًا اعتمادًا على استجابة غير صريحة من الـ API أو فرع `already saved` رغم أن الصورة لم تُخزن فعليًا | High | Low | Pending |
| B | على iPhone يحدث تعارض بين `auto capture` و`proactive capture` و/أو مسار `takePicture()` فينتج أكثر من حفظ أو صورة غير مستقرة | High | Low | Pending |
| C | صورة التسجيل التي تُحفظ على iPhone تختلف عن صورة التحقق بسبب اتجاه/انعكاس/إعادة ترميز، لذلك يتم الحفظ لكن التحقق يفشل لاحقًا | High | Medium | Pending |
| D | شاشة التحقق تستخدم صورة fallback أو حالة وجه قديمة لا تطابق آخر صورة مسجلة، فيظهر فشل التحقق بعد تسجيل يبدو ناجحًا | Medium | Medium | Pending |
| E | الخادم يستقبل الطلب من iPhone لكن يعيد نجاحًا شكليًا أو استثناءً مُلتقطًا لا تُفسره الواجهة بشكل صحيح | Medium | Low | Pending |

## Log Evidence
- Pending

## Verification Conclusion
- Pending

## Static Findings Before Runtime Reproduction
- Confirmed: Flutter uses new routes `/api/{clientId}/employee/face/save|verify|status`, but the server code originally exposed only `/api/{clientId}/biometric/face/enroll|verify|status`.
- Confirmed: Flutter comments and attendance flow assumed "stored employee face image", while the server originally stored only face embeddings in `EmployeeFaceTemplates` and did not persist the original image.
- Confirmed: `Users_Employees` schema in this repo has no face-image column, so the "save image in Users_Employees" flow was incomplete from the backend/data-model side.
- Confirmed: iPhone proactive capture loop could keep taking JPEGs every short interval, and the final save/verify path could immediately request another fresh capture, producing multiple still shots before a single logical save/verify attempt.

## Applied Fixes
- Added compatible server routes for:
  - `/api/{clientId}/employee/face/save`
  - `/api/{clientId}/employee/face/verify`
  - `/api/{clientId}/employee/face/status/{employeeNumber}`
- Extended server persistence to store the raw face image in `EmployeeFaceTemplates.FaceImageBase64` and timestamp it in `FaceImageUpdatedAt`.
- Added schema support for the new image columns in both runtime API guard code and `UpdateFaceBiometricSchema.ps1`.
- Enriched API responses/status with compatibility fields:
  - `HasFaceImage`
  - `IsRegistered`
  - `StorageMode`
  - `UsedLegacyFallback`
- Added endpoint-mode metadata in Flutter `FaceApiService` so fallback behavior becomes observable instead of silent.
- Throttled iPhone proactive capture in enrollment and verification to reuse a recent valid still image briefly instead of taking multiple images back-to-back.

## Expected Runtime Outcome After Patch
- Enrollment on iPhone should stop claiming a successful "image save" without an actual persisted face-image record.
- Attendance status should correctly report whether a stored face record exists.
- iPhone should take fewer redundant still shots before save/verify.
- Verification should hit the new route directly when the patched API is deployed, while still exposing whether any legacy fallback occurred.
