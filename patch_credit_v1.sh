#!/usr/bin/env bash
# شجرة عائلتي - شريط حقوق التصميم أسفل الصور المحفوظة والمشاركة
# "© تصميم : محمد برير حبيب الله" في الخريطة وبطاقة الفرد.
# شغّله من جذر المستودع: bash patch_credit_v1.sh
set -euo pipefail

m=lib/ui/mind_map_screen.dart
c=lib/ui/person_card.dart
test -f "$m" || { echo "ملف الخريطة غير موجود"; exit 1; }
test -f "$c" || { echo "ملف بطاقة الفرد غير موجود"; exit 1; }
grep -q "askImageQuality" "$m" || { echo "طبّق patch_image_quality_v1.sh أولاً"; exit 1; }
grep -q "Future<Uint8List> _capturePng() async {" "$m" || { echo "لم يُعثر على _capturePng في الخريطة"; exit 1; }
if grep -q "buildCreditBar" "$m"; then echo "مطبّق سابقاً"; exit 0; fi

# ───────────────────────── 1) نص الحقوق وشريطه (ملف مشترك) ─────────────────────────
cat > lib/ui/branding.dart <<'DART_EOF'
import 'package:flutter/material.dart';

/// نص حقوق التصميم الذي يظهر أسفل الصور المصدَّرة.
const String kCreditText = '© تصميم : محمد برير حبيب الله';

/// شريط الحقوق السفلي للخريطة المصدَّرة (أزرق بنص أبيض).
Widget buildCreditBar({double height = 40}) {
  return Container(
    height: height,
    alignment: Alignment.center,
    color: Colors.blue.shade700,
    child: const Text(
      kCreditText,
      textAlign: TextAlign.center,
      style: TextStyle(
        inherit: false,
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
DART_EOF

# ───────────────────────── 2) بطاقة الفرد: شريط حقوق بعد التذييل ─────────────────────────
credit_block="$(mktemp)"
cat > "$credit_block" <<'DART_EOF'
            Container(
              color: accent.shade700,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const Center(
                child: Text(
                  kCreditText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
DART_EOF

awk -v blockfile="$credit_block" '
  index($0, "padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),") { infooter = 1 }
  { print }
  infooter && $0 == "            )," {
    while ((getline l < blockfile) > 0) print l
    infooter = 0
  }
' "$c" > "$c.new"
mv "$c.new" "$c"
rm -f "$credit_block"
sed -i "s|^import 'ui_helpers.dart';|import 'branding.dart';\nimport 'ui_helpers.dart';|" "$c"
test "$(grep -c 'kCreditText' "$c")" = "1"
grep -q "import 'branding.dart';" "$c"

# ───────────────────────── 3) الخريطة: الشريط يظهر أثناء الالتقاط فقط ─────────────────────────
sed -i "s|import 'image_export.dart';|import 'branding.dart';\nimport 'image_export.dart';|" "$m"
sed -i "s|  Size? _lastViewport;|  Size? _lastViewport;\n  bool _exporting = false;|" "$m"
sed -i "s|final canvasW = (acc - gapX) + pad \* 2;|final canvasW = math.max((acc - gapX) + pad * 2, _exporting ? 340.0 : 0.0);|" "$m"
sed -i "s|final canvasH = layout.height + pad \* 2;|final footerH = _exporting ? 40.0 : 0.0;\n        final canvasH = layout.height + pad * 2 + footerH;|" "$m"
sed -i -e "/style: styles\[i\],/{" -e "n" -e "a\                        if (_exporting)\n                          Positioned(\n                            left: 0,\n                            right: 0,\n                            bottom: 0,\n                            height: footerH,\n                            child: buildCreditBar(height: footerH),\n                          )," -e "}" "$m"

grep -q "import 'branding.dart';" "$m"
grep -q "bool _exporting = false;" "$m"
grep -q "_exporting ? 340.0 : 0.0" "$m"
grep -q "final footerH = _exporting" "$m"
grep -q "buildCreditBar(height: footerH)" "$m"

# استبدال _capturePng: إظهار الشريط ثم الالتقاط ثم إخفاؤه
capture_new="$(mktemp)"
cat > "$capture_new" <<'DART_EOF'
  Future<Uint8List> _capturePng() async {
    // يظهر شريط حقوق التصميم أسفل الخريطة أثناء الالتقاط فقط
    setState(() => _exporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final ctx = _canvasKey.currentContext;
      if (ctx == null) throw StateError('الخريطة غير جاهزة بعد');
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
      final ratio = _quality.ratioFor(boundary.size);
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('فشل إنشاء الصورة');
      return data.buffer.asUint8List();
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
DART_EOF

awk -v newfile="$capture_new" '
  /^  Future<Uint8List> _capturePng\(\) async \{$/ {
    while ((getline line < newfile) > 0) print line
    skip = 1
    next
  }
  skip && /^  }$/ { skip = 0; next }
  !skip { print }
' "$m" > "$m.new"
mv "$m.new" "$m"
rm -f "$capture_new"
grep -q "await WidgetsBinding.instance.endOfFrame;" "$m"
test "$(grep -c 'Future<Uint8List> _capturePng() async' "$m")" = "1"

# ───────────────────────── 4) اختبار بسيط للنص ─────────────────────────
mkdir -p test
cat > test/branding_test.dart <<'DART_EOF'
import 'package:family_tree/ui/branding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('نص حقوق التصميم يحتوي الاسم الصحيح', () {
    expect(kCreditText, contains('محمد برير حبيب الله'));
    expect(kCreditText, startsWith('©'));
  });
}
DART_EOF

echo "تمت إضافة شريط حقوق التصميم."
