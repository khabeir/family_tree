#!/usr/bin/env bash
# شجرة عائلتي - مشاركة صورة الخريطة: زر ظاهر + اختيار الجودة + مشاركة كصورة أو كملف
# شغّله من جذر المستودع بعد patch_image_quality_v1.sh: bash patch_mindmap_share_v1.sh
set -euo pipefail

m=lib/ui/mind_map_screen.dart
test -f "$m" || { echo "ملف الخريطة غير موجود"; exit 1; }
grep -q "askImageQuality" "$m" || { echo "طبّق patch_image_quality_v1.sh أولاً"; exit 1; }
if grep -q "showShareOptions" "$m"; then echo "مطبّق سابقاً"; exit 0; fi

# ───────────────────────── 1) أدوات الصور: خيارات المشاركة ─────────────────────────
cat > lib/ui/image_export.dart <<'DART_EOF'
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// جودة الصورة المصدّرة. تحدّد الحد الأدنى لأطول ضلع ولمعامل التكبير،
/// مع سقف للأبعاد والذاكرة حتى لا ينهار التطبيق مع الخرائط الكبيرة.
enum ImageQuality {
  standard('عادية', 'حجم صغير، مناسبة للمعاينة', 1280, 1.0),
  fhd('FHD', 'أطول ضلع 1920 بكسل على الأقل (موصى بها)', 1920, 2.0),
  uhd('4K', 'أطول ضلع 3840 بكسل على الأقل، أعلى جودة وأكبر حجماً', 3840, 3.0);

  const ImageQuality(this.label, this.description, this.minSide, this.minRatio);

  final String label;
  final String description;
  final int minSide;
  final double minRatio;

  static const double maxSide = 8192;
  static const double maxPixels = 40e6;

  /// معامل التكبير للالتقاط من لوحة بحجم [size] (بالبكسل المنطقي).
  double ratioFor(Size size) {
    final longest = math.max(size.width, size.height);
    final pixels = math.max(size.width * size.height, 1.0);
    final wanted = math.max(minSide / longest, minRatio);
    final bySide = maxSide / longest;
    final byPixels = math.sqrt(maxPixels / pixels);
    return math.min(wanted, math.min(bySide, byPixels));
  }
}

Future<ImageQuality?> askImageQuality(
  BuildContext context,
  ImageQuality initial,
) {
  return showDialog<ImageQuality>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('جودة الصورة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final q in ImageQuality.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  q == initial
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(q.label),
                subtitle: Text(q.description),
                onTap: () => Navigator.of(ctx).pop(q),
              ),
            const Divider(),
            Text(
              'ملاحظة: واتساب يضغط الصور المرسلة كصورة. للحفاظ على الجودة أرسلها '
              'كـ «ملف/مستند» من قائمة المرفقات، أو احفظها هنا ثم أرسلها كمستند.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('إلغاء'),
        ),
      ],
    ),
  );
}

/// اختيار المستخدم عند المشاركة: الجودة، وهل تُرسل كصورة أم كملف.
class ShareChoice {
  const ShareChoice(this.quality, this.asDocument);

  final ImageQuality quality;
  final bool asDocument;
}

/// ورقة سفلية للمشاركة: جودة + «كصورة» أو «كملف».
Future<ShareChoice?> showShareOptions(
  BuildContext context, {
  required ImageQuality initial,
}) {
  var quality = initial;
  return showModalBottomSheet<ShareChoice>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'مشاركة الصورة',
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SegmentedButton<ImageQuality>(
                segments: [
                  for (final q in ImageQuality.values)
                    ButtonSegment(value: q, label: Text(q.label)),
                ],
                selected: {quality},
                onSelectionChanged: (s) =>
                    setSheetState(() => quality = s.first),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  quality.description,
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.of(ctx).pop(ShareChoice(quality, false)),
                icon: const Icon(Icons.image_outlined),
                label: const Text('مشاركة كصورة'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(ctx).pop(ShareChoice(quality, true)),
                icon: const Icon(Icons.attach_file),
                label: const Text('مشاركة كملف (بلا ضغط في واتساب)'),
              ),
              const SizedBox(height: 6),
              Text(
                '«كملف» يرسلها واتساب كمستند بجودتها الكاملة. وإن لم يظهر تطبيق '
                'تريده في القائمة فاستخدم «كصورة».',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String imageTimestamp() {
  final n = DateTime.now();
  String t(int v) => v.toString().padLeft(2, '0');
  return '${n.year}-${t(n.month)}-${t(n.day)}_${t(n.hour)}${t(n.minute)}';
}

/// يلتقط محتوى RepaintBoundary كاملاً (حتى لو كان خارج الشاشة) بصيغة PNG.
Future<Uint8List> captureBoundaryPng(GlobalKey key, ImageQuality quality) async {
  final ctx = key.currentContext;
  if (ctx == null) throw StateError('المحتوى غير جاهز بعد');
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
  final ratio = quality.ratioFor(boundary.size);
  final image = await boundary.toImage(pixelRatio: ratio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('فشل إنشاء الصورة');
  return data.buffer.asUint8List();
}

/// يحفظ الصورة في الجهاز عبر نافذة النظام. يعيد true عند الحفظ.
Future<bool> saveImageToDevice(Uint8List bytes, String fileName) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'حفظ الصورة',
    fileName: fileName,
    bytes: bytes,
  );
  return path != null;
}

/// يشارك الصورة عبر قائمة المشاركة. مع [asDocument] تُرسل كملف عام
/// (يعاملها واتساب كمستند فلا يضغطها).
Future<void> shareImageBytes(
  Uint8List bytes,
  String fileName, {
  String? subject,
  bool asDocument = false,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [
      XFile(
        file.path,
        mimeType: asDocument ? 'application/octet-stream' : 'image/png',
      ),
    ],
    subject: subject,
  );
}
DART_EOF

# ───────────────────────── 2) الخريطة: استبدال _shareImage ─────────────────────────
cat > /tmp/new_share.dart <<'DART_EOF'
  /// مشاركة الصورة: يختار المستخدم الجودة وهل تُرسل كصورة أم كملف.
  Future<void> _shareImage() async {
    try {
      final choice = await showShareOptions(context, initial: _quality);
      if (choice == null) return;
      _quality = choice.quality;
      final bytes = await _capturePng();
      await shareImageBytes(
        bytes,
        'family_tree_map_${_stamp()}.png',
        subject: 'خريطة العائلة',
        asDocument: choice.asDocument,
      );
    } catch (e) {
      if (mounted) showMessage(context, 'تعذّرت المشاركة: $e');
    }
  }
DART_EOF

awk '
  /^  \/\/\/ مشاركة الصورة عبر قائمة المشاركة/ { next }
  /^  Future<void> _shareImage\(\) async \{$/ {
    while ((getline line < "/tmp/new_share.dart") > 0) print line
    skip = 1
    next
  }
  skip && /^  }$/ { skip = 0; next }
  !skip { print }
' "$m" > "$m.new"
mv "$m.new" "$m"
grep -q "showShareOptions(context, initial: _quality)" "$m"
test "$(grep -c 'Future<void> _shareImage() async' "$m")" = "1"

# الاستيرادات التي لم تعد مستعملة في الخريطة (وإلا يفشل التحليل بتحذير)
if ! grep -q "File(\|Share\.\|XFile\|getTemporaryDirectory" "$m"; then
  sed -i "/^import 'dart:io';$/d; /^import 'package:path_provider\/path_provider.dart';$/d; /^import 'package:share_plus\/share_plus.dart';$/d" "$m"
else
  echo "تنبيه: ما زالت الخريطة تستعمل File/Share، لم تُحذف الاستيرادات"
fi

# ───────────────────────── 3) زر مشاركة ظاهر (الشريط العلوي + شريط ملء الشاشة) ─────────────────────────
sed -i "/_menuButton(root),\$/i\          IconButton(\n            tooltip: 'مشاركة الصورة',\n            icon: const Icon(Icons.share),\n            onPressed: _shareImage,\n          )," "$m"
test "$(grep -c "tooltip: 'مشاركة الصورة'" "$m")" = "2"

echo "تمت إضافة مشاركة صورة الخريطة."
