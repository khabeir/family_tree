#!/usr/bin/env bash
# شجرة عائلتي - جودة الصورة (عادية/FHD/4K) + بطاقة الشخص كصورة + زر حفظ في التفاصيل
# شغّله من جذر المستودع بعد تطبيق v3 وui_v1: bash patch_image_quality_v1.sh
set -euo pipefail

grep -q "_capturePng" lib/ui/mind_map_screen.dart || { echo "طبّق patch_mindmap_v3.sh أولاً"; exit 1; }
grep -q "_openMindMap" lib/ui/person_detail_screen.dart || { echo "طبّق patch_ui_v1.sh أولاً"; exit 1; }
if grep -q "askImageQuality" lib/ui/mind_map_screen.dart; then
  echo "مطبّق سابقاً"; exit 0
fi

mkdir -p lib/ui test

# ───────────────────────── 1) أدوات تصدير الصور المشتركة ─────────────────────────
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

Future<void> shareImageBytes(
  Uint8List bytes,
  String fileName, {
  String? subject,
}) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'image/png')],
    subject: subject,
  );
}
DART_EOF

# ───────────────────────── 2) بطاقة الشخص ─────────────────────────
cat > lib/ui/person_card.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/person.dart';
import '../domain/relations.dart';
import 'ui_helpers.dart';
import 'widgets.dart';

/// بطاقة مختصرة للشخص مصمَّمة للتصدير كصورة (خلفية بيضاء، بلا عناصر تفاعلية).
class PersonCard extends StatelessWidget {
  const PersonCard({super.key, required this.state, required this.person});

  final AppState state;
  final Person person;

  List<String> _marriageLines() {
    final p = person;
    final list = state.allMarriages
        .where((m) => m.person1Id == p.id || m.person2Id == p.id)
        .toList()
      ..sort((a, b) => a.id!.compareTo(b.id!));
    final lines = <String>[];
    for (final m in list) {
      final other = state.byId(m.person1Id == p.id ? m.person2Id : m.person1Id);
      final name = other == null ? 'غير معروف' : state.displayName(other);
      lines.add('$name — ${marriageStatusLabel(m.status)}');
    }
    return lines;
  }

  Widget _section(BuildContext context, String title, List<String> lines) {
    if (lines.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text('• $l', style: const TextStyle(height: 1.35)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = person;
    final theme = Theme.of(context);
    final MaterialColor color = switch (p.gender) {
      Gender.male => Colors.blue,
      Gender.female => Colors.pink,
      Gender.unknown => Colors.blueGrey,
    };

    final father = state.byId(p.fatherId);
    final mother = state.byId(p.motherId);
    final chain = paternalChain((id) => state.byId(id), p);
    final children = state.childrenOf(p.id!);
    final siblings = siblingsOf(state.all, p);

    return DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.black87),
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [color.shade50, color.shade200],
                ),
              ),
              child: Column(
                children: [
                  PersonAvatar(gender: p.gender, radius: 34),
                  const SizedBox(height: 10),
                  Text(
                    state.displayName(p),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(genderLabel(p.gender),
                      style: TextStyle(color: color.shade800)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (chain.isNotEmpty)
                    _section(context, 'سلسلة النسب', [
                      [p.name, ...chain.map((a) => a.name)].join('  ‹  '),
                    ]),
                  _section(context, 'الوالدان', [
                    if (father != null) 'الأب: ${state.displayName(father)}',
                    if (mother != null) 'الأم: ${state.displayName(mother)}',
                  ]),
                  _section(context, 'الزواج', _marriageLines()),
                  _section(context, 'الأبناء (${children.length})', [
                    for (final c in children) state.displayName(c),
                  ]),
                  _section(context, 'الإخوة والأخوات (${siblings.length})', [
                    for (final s in siblings)
                      '${siblingLabel(s)}: ${state.displayName(s.person)}',
                  ]),
                  if (p.notes != null) _section(context, 'ملاحظات', [p.notes!]),
                  const Divider(),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'شجرة عائلتي',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
DART_EOF

cat > lib/ui/person_card_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import 'image_export.dart';
import 'person_card.dart';
import 'ui_helpers.dart';
import 'widgets.dart';

/// معاينة بطاقة الشخص مع حفظها كصورة (بجودة تختارها) أو مشاركتها.
class PersonCardScreen extends StatefulWidget {
  const PersonCardScreen({
    super.key,
    required this.state,
    required this.personId,
  });

  final AppState state;
  final int personId;

  @override
  State<PersonCardScreen> createState() => _PersonCardScreenState();
}

class _PersonCardScreenState extends State<PersonCardScreen> {
  final _key = GlobalKey();
  ImageQuality _quality = ImageQuality.fhd;
  bool _busy = false;

  String get _fileName =>
      'person_card_${widget.personId}_${imageTimestamp()}.png';

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final bytes = await captureBoundaryPng(_key, _quality);
      final ok = await saveImageToDevice(bytes, _fileName);
      if (ok && mounted) showMessage(context, 'تم حفظ الصورة');
    } catch (e) {
      if (mounted) showMessage(context, 'تعذّر حفظ الصورة: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final bytes = await captureBoundaryPng(_key, _quality);
      await shareImageBytes(bytes, _fileName, subject: 'بطاقة شخص - شجرة عائلتي');
    } catch (e) {
      if (mounted) showMessage(context, 'تعذّرت المشاركة: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(title: const Text('بطاقة الشخص')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final person = state.byId(widget.personId);
          if (person == null) {
            return const EmptyState(
              icon: Icons.person_off_outlined,
              message: 'هذا الشخص غير موجود',
            );
          }
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: RepaintBoundary(
                          key: _key,
                          child: PersonCard(state: state, person: person),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                elevation: 8,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SegmentedButton<ImageQuality>(
                          segments: [
                            for (final q in ImageQuality.values)
                              ButtonSegment(value: q, label: Text(q.label)),
                          ],
                          selected: {_quality},
                          onSelectionChanged: (s) =>
                              setState(() => _quality = s.first),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _quality.description,
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _busy ? null : _save,
                                icon: const Icon(Icons.save_alt),
                                label: const Text('حفظ في الجهاز'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _share,
                                icon: const Icon(Icons.share),
                                label: const Text('مشاركة'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'لإبقاء الجودة في واتساب أرسل الصورة كمستند.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
DART_EOF

# ───────────────────────── 3) الخريطة الذهنية: اختيار الجودة قبل الحفظ/المشاركة ─────────────────────────
f=lib/ui/mind_map_screen.dart
sed -i "s|import 'ui_helpers.dart';|import 'image_export.dart';\nimport 'ui_helpers.dart';|" "$f"
sed -i "s|  Size? _lastViewport;|  Size? _lastViewport;\n  ImageQuality _quality = ImageQuality.fhd;|" "$f"
sed -i "/final longest = math.max(boundary.size.width, boundary.size.height);/d" "$f"
sed -i "s|final ratio = math.min(3.0, 5000 / longest);|final ratio = _quality.ratioFor(boundary.size);|" "$f"
sed -i "s|      final bytes = await _capturePng();|      final q = await askImageQuality(context, _quality);\n      if (q == null) return;\n      _quality = q;\n      final bytes = await _capturePng();|" "$f"
grep -q "import 'image_export.dart';" "$f"
grep -q "ImageQuality _quality" "$f"
grep -q "_quality.ratioFor(boundary.size)" "$f"
test "$(grep -c 'askImageQuality' "$f")" = "2"
if grep -q "final longest" "$f"; then echo "تعذّر تعديل _capturePng"; exit 1; fi

# ───────────────────────── 4) أزرار الحفظ في تفاصيل الشخص ─────────────────────────
d=lib/ui/person_detail_screen.dart
test "$(grep -c 'PopupMenuButton<String>(' "$d")" = "1"
sed -i "/import 'person_form_screen.dart';/a\import 'person_card_screen.dart';" "$d"
sed -i "/PopupMenuButton<String>(/i\              IconButton(\n                tooltip: 'حفظ كصورة',\n                icon: const Icon(Icons.save_alt),\n                onPressed: () => Navigator.of(context).push(\n                  MaterialPageRoute(\n                    builder: (_) =>\n                        PersonCardScreen(state: state, personId: personId),\n                  ),\n                ),\n              )," "$d"
sed -i -e "/label: const Text('الخريطة الذهنية'),/{" -e "n" -e "a\                    FilledButton.tonalIcon(\n                      onPressed: () => Navigator.of(context).push(\n                        MaterialPageRoute(\n                          builder: (_) =>\n                              PersonCardScreen(state: state, personId: personId),\n                        ),\n                      ),\n                      icon: const Icon(Icons.image_outlined),\n                      label: const Text('حفظ كصورة'),\n                    )," -e "}" "$d"
grep -q "import 'person_card_screen.dart';" "$d"
test "$(grep -c 'PersonCardScreen(state: state, personId: personId)' "$d")" = "2"

# ───────────────────────── 5) اختبار حساب الجودة ─────────────────────────
cat > test/image_quality_test.dart <<'DART_EOF'
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:family_tree/ui/image_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FHD: أطول ضلع 1920 بكسل على الأقل وبمعامل لا يقل عن 2', () {
    const size = Size(1000, 800);
    final r = ImageQuality.fhd.ratioFor(size);
    expect(r, greaterThanOrEqualTo(2.0));
    expect(size.width * r, greaterThanOrEqualTo(1920));
  });

  test('اللوحة الصغيرة تُكبَّر لتبلغ الحد الأدنى للضلع', () {
    final r = ImageQuality.standard.ratioFor(const Size(600, 400));
    expect(600 * r, closeTo(1280, 0.5));
    final r4k = ImageQuality.uhd.ratioFor(const Size(1000, 800));
    expect(1000 * r4k, closeTo(3840, 0.5));
  });

  test('الجودة تتزايد: عادية ≤ FHD ≤ 4K', () {
    const size = Size(900, 700);
    final a = ImageQuality.standard.ratioFor(size);
    final b = ImageQuality.fhd.ratioFor(size);
    final c = ImageQuality.uhd.ratioFor(size);
    expect(a, lessThanOrEqualTo(b));
    expect(b, lessThanOrEqualTo(c));
  });

  test('الخرائط الضخمة محدودة بالضلع الأقصى وعدد البكسلات', () {
    for (final q in ImageQuality.values) {
      const size = Size(6000, 4000);
      final r = q.ratioFor(size);
      expect(math.max(size.width, size.height) * r,
          lessThanOrEqualTo(ImageQuality.maxSide + 0.5));
      expect(size.width * size.height * r * r,
          lessThanOrEqualTo(ImageQuality.maxPixels + 1));
      expect(r, greaterThan(0));
    }
  });
}
DART_EOF

echo "تم تطبيق خيارات جودة الصورة وبطاقة الشخص."
