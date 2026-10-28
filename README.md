# شجرة عائلتي

تطبيق Android شخصي (Flutter + SQLite) لإدارة شجرة العائلة دون إنترنت ودون خادم.

## البناء
يُبنى عبر GitHub Actions (`.github/workflows/build.yml`): تحليل، اختبارات، ثم APK يُرفع كـ artifact.

## التوقيع الثابت (لتبقى البيانات عند تحديث التطبيق)
أضف أربعة Secrets في إعدادات المستودع (Settings → Secrets and variables → Actions):
`KEYSTORE_BASE64` و`KEYSTORE_PASSWORD` و`KEY_ALIAS` و`KEY_PASSWORD`.
لا تضع ملف المفتاح ولا كلمات المرور داخل المستودع، واحتفظ بنسخة من ملف `.jks` خارج GitHub.

## النسخ الاحتياطي
من التطبيق: أيقونة النسخ الاحتياطي ← تصدير (JSON)، واستعادته عند الحاجة.
