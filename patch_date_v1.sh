#!/usr/bin/env bash
# شجرة عائلتي - تاريخ اليوم في الصور المحفوظة والمشاركة
# شغّله من جذر المستودع بعد patch_credit_v1.sh وpatch_credit_phone_v1.sh: bash patch_date_v1.sh
set -euo pipefail

b=lib/ui/branding.dart
m=lib/ui/mind_map_screen.dart
c=lib/ui/person_card.dart
test -f "$b" || { echo "طبّق patch_credit_v1.sh أولاً"; exit 1; }
grep -q "kCreditPhone" "$b" || { echo "طبّق patch_credit_phone_v1.sh أولاً"; exit 1; }
grep -q "buildCreditBar(height: footerH)" "$m" || { echo "شريط الحقوق غير موجود في الخريطة (طبّق patch_credit_v1.sh)"; exit 1; }
if grep -q "exportDateText" "$b"; then echo "مطبّق سابقاً"; exit 0; fi

# ───────────────────────── 1) شريط الحقوق: سطر الحقوق + سطر التاريخ ─────────────────────────
cat > "$b" <<'DART_EOF'
import 'package:flutter/material.dart';

const String kCreditName = 'محمد برير حبيب الله';
const String kCreditPhone = '0914111214';

/// نص حقوق التصميم الذي يظهر أسفل الصور المصدَّرة.
const String kCreditText = '© تصميم : $kCreditName  •  $kCreditPhone';

/// تاريخ التصدير بصيغة yyyy-MM-dd (تاريخ جهازك وقت الحفظ أو المشاركة).
String exportDateText([DateTime? now]) {
  final n = now ?? DateTime.now();
  String t(int v) => v.toString().padLeft(2, '0');
  return 'تاريخ التصدير: ${n.year}-${t(n.month)}-${t(n.day)}';
}

/// شريط الحقوق السفلي للخريطة المصدَّرة: سطر الحقوق ثم تاريخ التصدير
/// (أزرق بنص أبيض، ويتقلّص النص إن ضاق العرض).
Widget buildCreditBar({double height = 58, DateTime? now}) {
  return Container(
    height: height,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    color: Colors.blue.shade700,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            kCreditText,
            textAlign: TextAlign.center,
            style: TextStyle(
              inherit: false,
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            exportDateText(now),
            textAlign: TextAlign.center,
            style: const TextStyle(
              inherit: false,
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}
DART_EOF

# ارتفاع الشريط في الخريطة 58 بدل 40 (سطران)
sed -i 's/_exporting ? 40\.0 : 0\.0/_exporting ? 58.0 : 0.0/' "$m"
grep -q "_exporting ? 58.0 : 0.0" "$m"

# ───────────────────────── 2) بطاقة الفرد: تسمية التاريخ في التذييل ─────────────────────────
if [ -f "$c" ] && grep -q "^ *_today(),\$" "$c"; then
  sed -i "s|^\( *\)_today(),\$|\1'التاريخ: ' + _today(),|" "$c"
  grep -q "'التاريخ: ' + _today()," "$c"
fi

# ───────────────────────── 3) اختبار ─────────────────────────
mkdir -p test
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

  test('تاريخ التصدير بصيغة yyyy-MM-dd مع أصفار بادئة', () {
    expect(exportDateText(DateTime(2026, 10, 30)), 'تاريخ التصدير: 2026-10-30');
    expect(exportDateText(DateTime(2026, 1, 5)), 'تاريخ التصدير: 2026-01-05');
  });
}
DART_EOF

echo "تمت إضافة تاريخ اليوم إلى الصور المحفوظة والمشاركة."
