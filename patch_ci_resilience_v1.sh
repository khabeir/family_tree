#!/usr/bin/env bash
# شجرة عائلتي - مقاومة أعطال الشبكة في بناء GitHub Actions:
# كاش Gradle + مستودعات بديلة + مهلات وإعادة محاولة + إعادة البناء 3 مرات.
# شغّله من جذر المستودع: bash patch_ci_resilience_v1.sh
set -euo pipefail

test -f .github/workflows/build.yml || { echo "ملف GitHub Actions غير موجود"; exit 1; }
test -f tool/prepare_android.sh || { echo "طبّق setup_release_v1.sh أولاً"; exit 1; }

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
    timeout-minutes: 45
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

      - name: Gradle cache
        uses: actions/cache@v4
        with:
          path: |
            ~/.gradle/caches
            ~/.gradle/wrapper
          key: gradle-${{ runner.os }}-flutter-3.24.5-v1
          restore-keys: |
            gradle-${{ runner.os }}-flutter-

      - name: Gradle network resilience (mirrors, timeouts, retries)
        run: |
          mkdir -p ~/.gradle/init.d
          cat > ~/.gradle/init.d/mirrors.gradle <<'GRADLE_EOF'
          // مستودعات بديلة تُجرَّب بعد المستودعات الأصلية إن تعذّر حلّ اعتماد
          allprojects {
              buildscript {
                  repositories {
                      maven { url = uri('https://maven-central.storage-download.googleapis.com/maven2/') }
                      maven { url = uri('https://repo1.maven.org/maven2/') }
                  }
              }
              repositories {
                  maven { url = uri('https://maven-central.storage-download.googleapis.com/maven2/') }
                  maven { url = uri('https://repo1.maven.org/maven2/') }
              }
          }
          GRADLE_EOF
          cat >> ~/.gradle/gradle.properties <<'PROPS_EOF'
          systemProp.org.gradle.internal.http.connectionTimeout=120000
          systemProp.org.gradle.internal.http.socketTimeout=120000
          systemProp.org.gradle.internal.repository.max.retries=6
          systemProp.org.gradle.internal.repository.initial.backoff=500
          PROPS_EOF

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

      - name: Build APK (up to 3 attempts)
        run: |
          for i in 1 2 3; do
            if flutter build apk --release --build-number=${{ github.run_number }}; then
              exit 0
            fi
            echo "Build attempt $i failed; retrying in 20s..."
            sleep 20
          done
          exit 1

      - uses: actions/upload-artifact@v4
        with:
          name: family-tree-apk-${{ github.run_number }}
          path: build/app/outputs/flutter-apk/app-release.apk
          if-no-files-found: error
WORKFLOW_EOF

grep -q "Build APK (up to 3 attempts)" .github/workflows/build.yml
grep -q "mirrors.gradle" .github/workflows/build.yml
echo "تم تحديث ملف GitHub Actions."
