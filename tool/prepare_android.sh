#!/usr/bin/env bash
# يُشغَّل في CI بعد flutter create لتخصيص مجلد android المولَّد:
# اسم التطبيق، الأيقونة، والتوقيع الثابت (إن وُجد KEYSTORE_PATH).
set -euo pipefail

MANIFEST=android/app/src/main/AndroidManifest.xml
GRADLE=android/app/build.gradle

test -f "$MANIFEST" || { echo "AndroidManifest.xml غير موجود"; exit 1; }

# 1) اسم التطبيق بالعربية
sed -i 's|android:label="[^"]*"|android:label="شجرة عائلتي"|' "$MANIFEST"
grep -q 'android:label="شجرة عائلتي"' "$MANIFEST"

# 2) الأيقونة
mkdir -p android/app/src/main/res
cp -r tool/android_res/. android/app/src/main/res/

# 3) التوقيع الثابت
if [ -n "${KEYSTORE_PATH:-}" ] && [ -f "${KEYSTORE_PATH}" ]; then
  test -f "$GRADLE" || { echo "android/app/build.gradle غير موجود (قالب Kotlin DSL غير مدعوم هنا)"; exit 1; }
  if ! grep -q "signingConfigs.release" "$GRADLE"; then
    sed -i '/^    buildTypes {/i\    signingConfigs {\n        release {\n            storeFile file(System.getenv("KEYSTORE_PATH"))\n            storePassword System.getenv("KEYSTORE_PASSWORD")\n            keyAlias System.getenv("KEY_ALIAS")\n            keyPassword System.getenv("KEY_PASSWORD")\n        }\n    }\n' "$GRADLE"
    sed -i -E 's/signingConfig[[:space:]]*=?[[:space:]]*signingConfigs\.debug/signingConfig = signingConfigs.release/' "$GRADLE"
  fi
  grep -q "signingConfigs {" "$GRADLE" || { echo "تعذّر إضافة signingConfigs"; exit 1; }
  grep -q "signingConfigs.release" "$GRADLE" || { echo "تعذّر ربط release بالتوقيع"; exit 1; }
  echo "تم ضبط التوقيع الثابت"
else
  echo "لا يوجد مفتاح توقيع: سيُستخدم مفتاح debug (لن تُثبَّت النسخ فوق بعضها)"
fi
