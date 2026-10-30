#!/usr/bin/env bash
# شجرة عائلتي - شريط واحد رفيع أسفل الصور: التصميم أقصى اليمين وتاريخ التصدير أقصى اليسار
# (بديل عن patch_date_v1.sh؛ يصلح سواء طبّقته أم لا)
# شغّله من جذر المستودع بعد patch_credit_v1.sh وpatch_credit_phone_v1.sh: bash patch_credit_compact_v1.sh
set -euo pipefail

b=lib/ui/branding.dart
m=lib/ui/mind_map_screen.dart
c=lib/ui/person_card.dart
test -f "$b" || { echo "طبّق patch_credit_v1.sh أولاً"; exit 1; }
grep -q "kCreditPhone" "$b" || { echo "طبّق patch_credit_phone_v1.sh أولاً"; exit 1; }
grep -q "buildCreditBar(height: footerH)" "$m" || { echo "شريط الحقوق غير موجود في الخريطة (طبّق patch_credit_v1.sh)"; exit 1; }
grep -q "kCreditText" "$c" || { echo "شريط الحقوق غير موجود في بطاقة الفرد (طبّق patch_credit_v1.sh)"; exit 1; }
if grep -q "horizontal: 14, vertical: 8" "$c" && grep -q "AlignmentDirectional.centerStart" "$c"; then
  echo "مطبّق سابقاً"; exit 0
fi

# ───────────────────────── 1) شريط الخريطة: سطر واحد (حقوق يميناً، تاريخ يساراً) ─────────────────────────
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

/// شريط رفيع بسطر واحد أسفل الخريطة المصدَّرة:
/// الحقوق عند أقصى اليمين (بداية السطر في العربية) والتاريخ عند أقصى اليسار.
Widget buildCreditBar({double height = 32, DateTime? now}) {
  return Container(
    height: height,
    color: Colors.blue.shade700,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        const Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              kCreditText,
              style: TextStyle(
                inherit: false,
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          exportDateText(now),
          style: const TextStyle(
            inherit: false,
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
DART_EOF

# ارتفاع الشريط 32 وعرض أدنى 460 ليتّسع السطر عند تصدير خريطة صغيرة
sed -i 's/final footerH = _exporting ? [0-9.]* : 0\.0;/final footerH = _exporting ? 32.0 : 0.0;/' "$m"
sed -i 's/math\.max((acc - gapX) + pad \* 2, _exporting ? [0-9.]* : 0\.0)/math.max((acc - gapX) + pad * 2, _exporting ? 460.0 : 0.0)/' "$m"
grep -q "final footerH = _exporting ? 32.0 : 0.0;" "$m"
grep -q "_exporting ? 460.0 : 0.0" "$m"

# ───────────────────────── 2) بطاقة الفرد: استبدال التذييل وشريط الحقوق بشريط واحد ─────────────────────────
block="$(mktemp)"
cat > "$block" <<'DART_EOF'
            Container(
              color: accent.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        kCreditText,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'تاريخ التصدير: ' + _today(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
DART_EOF

awk -v blockfile="$block" '
  { lines[NR] = $0 }
  END {
    trig = 0
    for (i = 1; i <= NR; i++) {
      if (index(lines[i], "padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),")) { trig = i; break }
    }
    if (trig == 0) { print "لم يُعثر على تذييل البطاقة" > "/dev/stderr"; exit 3 }
    start = trig - 2
    if (lines[start] != "            Container(") { print "بنية التذييل غير متوقعة" > "/dev/stderr"; exit 3 }
    cnt = 0; endl = 0
    for (i = trig; i <= NR; i++) {
      if (lines[i] == "            ),") { cnt++; if (cnt == 2) { endl = i; break } }
    }
    if (endl == 0) { print "لم يُعثر على نهاية شريط الحقوق" > "/dev/stderr"; exit 3 }
    for (i = 1; i <= NR; i++) {
      if (i == start) { while ((getline l < blockfile) > 0) print l }
      if (i >= start && i <= endl) continue
      print lines[i]
    }
  }
' "$c" > "$c.new" || { rm -f "$c.new" "$block"; echo "تعذّر تعديل بطاقة الفرد؛ لم يتغير الملف"; exit 1; }
mv "$c.new" "$c"
rm -f "$block"

test "$(grep -c 'kCreditText' "$c")" = "1"
grep -q "AlignmentDirectional.centerStart" "$c"
test "$(grep -c 'horizontal: 20, vertical: 12' "$c")" = "0"
test "$(grep -c '_today()' "$c")" -ge "2"

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

echo "تم: شريط رفيع بسطر واحد (التصميم يميناً والتاريخ يساراً) في الخريطة وبطاقة الفرد."
