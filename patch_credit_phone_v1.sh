#!/usr/bin/env bash
# شجرة عائلتي - إضافة رقم الهاتف بعد اسم المصمم في شريط الحقوق
# شغّله من جذر المستودع بعد patch_credit_v1.sh: bash patch_credit_phone_v1.sh
set -euo pipefail

b=lib/ui/branding.dart
test -f "$b" || { echo "طبّق patch_credit_v1.sh أولاً"; exit 1; }

cat > "$b" <<'DART_EOF'
import 'package:flutter/material.dart';

const String kCreditName = 'محمد برير حبيب الله';
const String kCreditPhone = '0914111214';

/// نص حقوق التصميم الذي يظهر أسفل الصور المصدَّرة.
const String kCreditText = '© تصميم : $kCreditName  •  $kCreditPhone';

/// شريط الحقوق السفلي للخريطة المصدَّرة (أزرق بنص أبيض، ويتقلّص النص إن ضاق العرض).
Widget buildCreditBar({double height = 40}) {
  return Container(
    height: height,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    color: Colors.blue.shade700,
    child: const FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        kCreditText,
        textAlign: TextAlign.center,
        style: TextStyle(
          inherit: false,
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
DART_EOF

# عرض أدنى أكبر قليلاً للخريطة الصغيرة أثناء التصدير ليتّسع النص
m=lib/ui/mind_map_screen.dart
if [ -f "$m" ]; then
  sed -i 's/_exporting ? 340\.0 : 0\.0/_exporting ? 380.0 : 0.0/' "$m"
fi

cat > test/branding_test.dart <<'DART_EOF'
import 'package:family_tree/ui/branding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('نص حقوق التصميم: الاسم ثم رقم الهاتف', () {
    expect(kCreditText, startsWith('©'));
    expect(kCreditText, contains('محمد برير حبيب الله'));
    expect(kCreditText, contains('0914111214'));
    expect(
      kCreditText.indexOf('0914111214'),
      greaterThan(kCreditText.indexOf('محمد برير حبيب الله')),
    );
  });
}
DART_EOF

grep -q "kCreditPhone" "$b"
echo "تمت إضافة رقم الهاتف إلى شريط الحقوق."
