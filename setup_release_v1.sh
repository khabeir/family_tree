#!/usr/bin/env bash
# شجرة عائلتي - إعداد الإصدار v1:
#  - توقيع ثابت عبر GitHub Secrets (التحديث فوق النسخة القديمة يحفظ البيانات)
#  - اسم التطبيق بالعربية وأيقونة شجرة
#  - رقم بناء متزايد (versionCode) في كل تشغيل
#  - تنبيه عند إضافة اسم مكرر بالاسم الكامل
# شغّله من جذر المستودع: bash setup_release_v1.sh
set -euo pipefail

test -f .github/workflows/build.yml || { echo "ملف GitHub Actions غير موجود"; exit 1; }
test -f lib/ui/person_form_screen.dart || { echo "طبّق المراحل السابقة أولاً"; exit 1; }

mkdir -p tool/android_res/values tool/android_res/drawable tool/android_res/mipmap-anydpi-v26

# ───────────────────────── 1) أيقونة التطبيق (متجهة، بلا صور) ─────────────────────────
cat > tool/android_res/values/colors.xml <<'XML_EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#2E7D32</color>
</resources>
XML_EOF

cat > tool/android_res/drawable/ic_launcher_foreground.xml <<'XML_EOF'
<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <!-- شجرة: تاج من ثلاث دوائر وجذع -->
    <path
        android:fillColor="#FFFFFFFF"
        android:pathData="M36,44 a18,18 0 1,0 36,0 a18,18 0 1,0 -36,0 z
                          M28,56 a12,12 0 1,0 24,0 a12,12 0 1,0 -24,0 z
                          M56,56 a12,12 0 1,0 24,0 a12,12 0 1,0 -24,0 z
                          M50,60 L58,60 L58,82 L50,82 Z" />
</vector>
XML_EOF

cat > tool/android_res/mipmap-anydpi-v26/ic_launcher.xml <<'XML_EOF'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
</adaptive-icon>
XML_EOF

# ───────────────────────── 2) تخصيص منصة أندرويد المولَّدة في CI ─────────────────────────
cat > tool/prepare_android.sh <<'SH_EOF'
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
SH_EOF
chmod +x tool/prepare_android.sh

# ───────────────────────── 3) GitHub Actions ─────────────────────────
cat > .github/workflows/build.yml <<'WORKFLOW_EOF'
name: Build APK

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:

concurrency:
  group: build-${{ github.ref }}
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    env:
      KEYSTORE_BASE64: ${{ secrets.KEYSTORE_BASE64 }}
      KEYSTORE_PASSWORD: ${{ secrets.KEYSTORE_PASSWORD }}
      KEY_ALIAS: ${{ secrets.KEY_ALIAS }}
      KEY_PASSWORD: ${{ secrets.KEY_PASSWORD }}
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: '3.24.5'
          cache: true

      - name: SQLite for tests
        run: sudo apt-get update && sudo apt-get install -y libsqlite3-dev

      - name: Create Android platform if missing
        run: |
          if [ ! -d android ]; then
            flutter create --platforms=android --org com.familytree.personal --project-name family_tree .
            rm -f test/widget_test.dart
          fi

      - name: Decode signing key (if provided)
        run: |
          if [ -n "$KEYSTORE_BASE64" ]; then
            echo "$KEYSTORE_BASE64" | base64 -d > "$RUNNER_TEMP/release.jks"
            echo "KEYSTORE_PATH=$RUNNER_TEMP/release.jks" >> "$GITHUB_ENV"
            echo "Fixed release key found"
          else
            echo "No signing secrets: debug key will be used"
          fi

      - name: Prepare Android (label, icon, signing)
        run: bash tool/prepare_android.sh

      - run: flutter --version
      - run: flutter pub get
      - run: flutter analyze --no-fatal-infos
      - run: flutter test
      - run: flutter build apk --release --build-number=${{ github.run_number }}

      - uses: actions/upload-artifact@v4
        with:
          name: family-tree-apk-${{ github.run_number }}
          path: build/app/outputs/flutter-apk/app-release.apk
          if-no-files-found: error
WORKFLOW_EOF

# ───────────────────────── 4) README مختصر ─────────────────────────
if [ ! -f README.md ]; then
cat > README.md <<'MD_EOF'
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
MD_EOF
fi

# ───────────────────────── 5) تنبيه الاسم المكرر عند الحفظ ─────────────────────────
f=lib/ui/person_form_screen.dart
if ! grep -q "اسم مكرر" "$f"; then
  test "$(grep -c 'final ok = await runGuarded(context, () async {' "$f")" = "1"
  sed -i "s|import '../app_state.dart';|import '../app_state.dart';\nimport '../core/arabic_text.dart';|" "$f"
  sed -i "/final ok = await runGuarded(context, () async {/i\    final fullName = widget.state\n        .composeName(person.name, person.fatherId, selfId: base?.id);\n    final nameChanged = base == null ||\n        base.name != person.name.trim().replaceAll(RegExp(r'\\\\s+'), ' ') ||\n        base.fatherId != person.fatherId;\n    final duplicate = widget.state.all.any((o) =>\n        o.id != base?.id \&\&\n        normalizeArabic(widget.state.displayName(o)) == normalizeArabic(fullName));\n    if (nameChanged \&\& duplicate) {\n      final go = await confirmDialog(\n        context,\n        title: 'اسم مكرر',\n        message: 'يوجد شخص بالاسم الكامل نفسه: ' + fullName + '. هل تريد المتابعة؟',\n        confirmLabel: 'متابعة',\n      );\n      if (!go || !mounted) {\n        if (mounted) setState(() => _saving = false);\n        return;\n      }\n    }\n" "$f"
fi
grep -q "اسم مكرر" "$f"
grep -q "import '../core/arabic_text.dart';" "$f"
grep -q "nameChanged && duplicate" "$f"

echo "تم إعداد الإصدار v1."
echo "الخطوة التالية: أنشئ مفتاح التوقيع وأضف الـ Secrets (انظر الشرح)."
