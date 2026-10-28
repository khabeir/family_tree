#!/usr/bin/env bash
# شجرة عائلتي - تحسين المظهر v2 + إعادة تصميم بطاقة الفرد المحفوظة كصورة
# شغّله من جذر المستودع بعد patch_image_quality_v1.sh: bash patch_ui_v2.sh
set -euo pipefail

for f in lib/ui/person_card_screen.dart lib/ui/person_card.dart lib/ui/image_export.dart \
         lib/ui/widgets.dart lib/ui/person_detail_screen.dart lib/ui/tree_screen.dart; do
  test -f "$f" || { echo "ملف ناقص: $f (طبّق التحسينات السابقة أولاً)"; exit 1; }
done

# ───────────────────────── 1) السمة: فاتح + داكن (حسب النظام) ─────────────────────────
cat > lib/main.dart <<'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'data/database/app_database.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  final state = AppState(db);
  await state.load();
  runApp(FamilyTreeApp(state: state));
}

ThemeData _buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2E7D32),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(centerTitle: true, scrolledUnderElevation: 1),
    cardTheme: CardTheme(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

class FamilyTreeApp extends StatelessWidget {
  const FamilyTreeApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شجرة عائلتي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: HomeScreen(state: state),
    );
  }
}
DART_EOF

# ترويسة تفاصيل الشخص: ألوان تتكيف مع الفاتح والداكن
d=lib/ui/person_detail_screen.dart
sed -i "s|color: const Color(0xBFFFFFFF),|color: theme.colorScheme.surface.withAlpha(200),|" "$d"
sed -i "s|colors: \[color.shade50, color.shade100\],|colors: [\n            Color.alphaBlend(color.withAlpha(46), theme.colorScheme.surface),\n            Color.alphaBlend(color.withAlpha(90), theme.colorScheme.surface),\n          ],|" "$d"
sed -i "s|copyWith(color: color.shade800),|copyWith(color: color),|" "$d"
grep -q "surface.withAlpha(200)" "$d"
grep -q "alphaBlend(color.withAlpha(46)" "$d"
grep -q "copyWith(color: color)," "$d"

# ───────────────────────── 2) بطاقة الفرد (للتصدير كصورة) ─────────────────────────
cat > lib/ui/person_card.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/person.dart';
import '../domain/relations.dart';
import 'ui_helpers.dart';

/// أقسام البطاقة التي يمكن إظهارها أو إخفاؤها.
enum CardSection {
  stats('الإحصاءات'),
  lineage('سلسلة النسب'),
  parents('الوالدان'),
  marriages('الزواج'),
  children('الأبناء'),
  siblings('الإخوة'),
  notes('الملاحظات');

  const CardSection(this.label);

  final String label;
}

const List<MaterialColor> cardPalette = [
  Colors.blue,
  Colors.pink,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.brown,
  Colors.indigo,
];

MaterialColor cardAccentFor(Gender g) => switch (g) {
      Gender.male => Colors.blue,
      Gender.female => Colors.pink,
      Gender.unknown => Colors.teal,
    };

/// بطاقة الفرد: عرض ثابت 480، خلفية بيضاء، مصمّمة لتُلتقط كصورة عالية الدقة.
class PersonCard extends StatelessWidget {
  const PersonCard({
    super.key,
    required this.state,
    required this.person,
    this.accent,
    this.sections = const {...CardSection.values},
  });

  static const double width = 480;

  final AppState state;
  final Person person;
  final MaterialColor? accent;
  final Set<CardSection> sections;

  String _today() {
    final n = DateTime.now();
    String t(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${t(n.month)}-${t(n.day)}';
  }

  Widget _chip(
    String text, {
    required Color bg,
    required Color fg,
    IconData? icon,
    FontWeight weight = FontWeight.w600,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              text,
              style: TextStyle(color: fg, fontSize: 14, fontWeight: weight),
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color) _genderColors(Gender g) => switch (g) {
        Gender.male => (Colors.blue.shade50, Colors.blue.shade800),
        Gender.female => (Colors.pink.shade50, Colors.pink.shade800),
        Gender.unknown => (Colors.blueGrey.shade50, Colors.blueGrey.shade700),
      };

  Widget _genderChip(String text, Gender g) {
    final (bg, fg) = _genderColors(g);
    return _chip(text, bg: bg, fg: fg);
  }

  Widget _title(MaterialColor accent, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accent.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: accent.shade700),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: accent.shade800,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Divider(height: 1, color: accent.shade100)),
        ],
      ),
    );
  }

  Widget _stat(MaterialColor accent, int value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: accent.shade800,
            ),
          ),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _infoRow(MaterialColor accent, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accent.shade600),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = person;
    final accent = this.accent ?? cardAccentFor(p.gender);

    final father = state.byId(p.fatherId);
    final mother = state.byId(p.motherId);
    final chain = paternalChain((id) => state.byId(id), p);
    final children = state.childrenOf(p.id!);
    final siblings = siblingsOf(state.all, p);
    final marriages = state.allMarriages
        .where((m) => m.person1Id == p.id || m.person2Id == p.id)
        .toList()
      ..sort((a, b) => a.id!.compareTo(b.id!));

    bool show(CardSection s) => sections.contains(s);

    final body = <Widget>[];

    if (show(CardSection.lineage) && chain.isNotEmpty) {
      body.add(_title(accent, Icons.timeline, 'سلسلة النسب'));
      body.add(
        Wrap(
          spacing: 6,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _chip(p.name, bg: accent.shade700, fg: Colors.white),
            for (final a in chain) ...[
              const Icon(Icons.chevron_left, size: 16, color: Colors.black38),
              _chip(a.name, bg: Colors.grey.shade100, fg: Colors.black87),
            ],
          ],
        ),
      );
    }

    if (show(CardSection.parents) && (father != null || mother != null)) {
      body.add(_title(accent, Icons.family_restroom, 'الوالدان'));
      if (father != null) {
        body.add(_infoRow(accent, Icons.man, 'الأب', state.displayName(father)));
      }
      if (mother != null) {
        body.add(_infoRow(accent, Icons.woman, 'الأم', state.displayName(mother)));
      }
    }

    if (show(CardSection.marriages) && marriages.isNotEmpty) {
      body.add(_title(accent, Icons.favorite, 'الزواج'));
      for (final m in marriages) {
        final other = state.byId(m.person1Id == p.id ? m.person2Id : m.person1Id);
        body.add(
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accent.shade50,
              border: Border.all(color: accent.shade100),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.favorite, size: 18, color: Colors.red.shade300),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    other == null ? 'غير معروف' : state.displayName(other),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                _chip(
                  marriageStatusLabel(m.status),
                  bg: Colors.white,
                  fg: accent.shade800,
                ),
              ],
            ),
          ),
        );
      }
    }

    if (show(CardSection.children) && children.isNotEmpty) {
      body.add(_title(accent, Icons.child_care, 'الأبناء (${children.length})'));
      const maxShown = 40;
      body.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in children.take(maxShown)) _genderChip(c.name, c.gender),
            if (children.length > maxShown)
              _chip('+${children.length - maxShown}',
                  bg: Colors.grey.shade200, fg: Colors.black87),
          ],
        ),
      );
    }

    if (show(CardSection.siblings) && siblings.isNotEmpty) {
      body.add(
        _title(accent, Icons.people_outline, 'الإخوة والأخوات (${siblings.length})'),
      );
      body.add(
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in siblings.take(40))
              _genderChip('${s.person.name} · ${siblingLabel(s)}', s.person.gender),
          ],
        ),
      );
    }

    if (show(CardSection.notes) && p.notes != null) {
      body.add(_title(accent, Icons.notes, 'ملاحظات'));
      body.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            border: BorderDirectional(
              start: BorderSide(color: Colors.amber.shade600, width: 4),
            ),
          ),
          child: Text(p.notes!),
        ),
      );
    }

    return DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.35),
      child: Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [accent.shade700, accent.shade400],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: accent.shade50,
                      foregroundColor: accent.shade700,
                      child: Icon(genderIcon(p.gender), size: 44),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    state.displayName(p),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      genderLabel(p.gender),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (show(CardSection.stats))
              Container(
                color: accent.shade50,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    _stat(accent, children.length, 'الأبناء'),
                    _stat(accent, marriages.length, 'الزواج'),
                    _stat(accent, siblings.length, 'الإخوة'),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: body.isEmpty
                    ? [
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('لا توجد بيانات إضافية لعرضها',
                                style: TextStyle(color: Colors.black54)),
                          ),
                        ),
                      ]
                    : body,
              ),
            ),
            Container(
              color: accent.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.account_tree, size: 16, color: accent.shade700),
                  const SizedBox(width: 6),
                  Text(
                    'شجرة عائلتي',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: accent.shade800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _today(),
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
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

# ───────────────────────── 3) شاشة حفظ البطاقة: لون + محتوى + جودة ─────────────────────────
cat > lib/ui/person_card_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import 'image_export.dart';
import 'person_card.dart';
import 'ui_helpers.dart';
import 'widgets.dart';

/// معاينة بطاقة الفرد مع اختيار اللون والمحتوى والجودة ثم الحفظ أو المشاركة.
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
  MaterialColor? _accent; // null = تلقائي حسب الجنس
  Set<CardSection> _sections = {...CardSection.values};
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

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _swatch({MaterialColor? color, required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _accent = color),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color ?? Colors.grey.shade300,
          border: Border.all(
            color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: color == null
            ? const Icon(Icons.auto_awesome, size: 16, color: Colors.black54)
            : (selected
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : null),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(title: const Text('بطاقة الفرد كصورة')),
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
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(14),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 14,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: PersonCard.width,
                          child: RepaintBoundary(
                            key: _key,
                            child: PersonCard(
                              state: state,
                              person: person,
                              accent: _accent,
                              sections: _sections,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Material(
                elevation: 10,
                child: SafeArea(
                  top: false,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.42,
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('لون البطاقة'),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _swatch(selected: _accent == null),
                              for (final c in cardPalette)
                                _swatch(color: c, selected: _accent == c),
                            ],
                          ),
                          _label('المحتوى'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              for (final s in CardSection.values)
                                FilterChip(
                                  label: Text(s.label),
                                  selected: _sections.contains(s),
                                  onSelected: (on) => setState(() {
                                    final next = {..._sections};
                                    on ? next.add(s) : next.remove(s);
                                    _sections = next;
                                  }),
                                ),
                            ],
                          ),
                          _label('الجودة'),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<ImageQuality>(
                              segments: [
                                for (final q in ImageQuality.values)
                                  ButtonSegment(value: q, label: Text(q.label)),
                              ],
                              selected: {_quality},
                              onSelectionChanged: (s) =>
                                  setState(() => _quality = s.first),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _quality.description,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: _busy ? null : _save,
                                  icon: _busy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.save_alt),
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
              ),
            ],
          );
        },
      ),
    );
  }
}
DART_EOF

# ───────────────────────── 4) قائمة الأفراد: لافتة إحصاءات ─────────────────────────
cat > lib/ui/person_list_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/person.dart';
import 'backup_screen.dart';
import 'import_screen.dart';
import 'person_detail_screen.dart';
import 'person_form_screen.dart';
import 'widgets.dart';

class PersonListScreen extends StatefulWidget {
  const PersonListScreen({super.key, required this.state});

  final AppState state;

  @override
  State<PersonListScreen> createState() => _PersonListScreenState();
}

class _PersonListScreenState extends State<PersonListScreen> {
  final _controller = TextEditingController();
  String _query = '';
  Gender? _gender;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PersonFormScreen(state: widget.state),
      ),
    );
  }

  Widget _banner(
    BuildContext context,
    int total,
    int males,
    int females,
    int marriages,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final on = scheme.onPrimary;

    Widget mini(IconData icon, String label, int value) {
      return Expanded(
        child: Column(
          children: [
            Icon(icon, color: on.withAlpha(220), size: 20),
            const SizedBox(height: 2),
            Text(
              '$value',
              style: TextStyle(
                color: on,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: on.withAlpha(200), fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [scheme.primary, scheme.tertiary],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total',
                  style: TextStyle(
                    color: on,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'فرداً في شجرة العائلة',
                  style: TextStyle(color: on.withAlpha(220)),
                ),
              ],
            ),
          ),
          mini(Icons.man, 'ذكور', males),
          mini(Icons.woman, 'إناث', females),
          mini(Icons.favorite, 'زيجات', marriages),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('شجرة عائلتي'),
        actions: [
          IconButton(
            tooltip: 'استيراد Excel / CSV',
            icon: const Icon(Icons.table_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ImportScreen(state: state)),
            ),
          ),
          IconButton(
            tooltip: 'النسخ الاحتياطي والبيانات',
            icon: const Icon(Icons.save_alt),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BackupScreen(state: state)),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final all = state.all;
          final males = all.where((p) => p.gender == Gender.male).length;
          final females = all.where((p) => p.gender == Gender.female).length;
          final items = state
              .search(_query)
              .where((p) => _gender == null || p.gender == _gender)
              .toList();

          return Column(
            children: [
              _banner(context, all.length, males, females,
                  state.allMarriages.length),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'ابحث بالاسم (يعمل على الاسم الكامل)',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final entry in <(String, Gender?)>[
                      ('الكل', null),
                      ('ذكور', Gender.male),
                      ('إناث', Gender.female),
                    ]) ...[
                      ChoiceChip(
                        label: Text(entry.$1),
                        selected: _gender == entry.$2,
                        onSelected: (_) => setState(() => _gender = entry.$2),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    Text('${items.length} نتيجة',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: items.isEmpty
                    ? EmptyState(
                        icon: all.isEmpty
                            ? Icons.family_restroom
                            : Icons.search_off,
                        message: all.isEmpty
                            ? 'لا يوجد أفراد بعد.\nأضف أول شخص، أو حمّل بيانات تجريبية من أيقونة النسخ الاحتياطي.'
                            : 'لا نتائج مطابقة',
                        action: all.isEmpty
                            ? FilledButton.icon(
                                onPressed: _add,
                                icon: const Icon(Icons.person_add),
                                label: const Text('إضافة شخص'),
                              )
                            : null,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final p = items[i];
                          final parents = state.parentsLabel(p);
                          final kids = state.childrenOf(p.id!).length;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Card(
                              child: ListTile(
                                leading: PersonAvatar(gender: p.gender),
                                title: Text(
                                  state.displayName(p),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: parents == null ? null : Text(parents),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (kids > 0) ...[
                                      const Icon(Icons.child_care, size: 16),
                                      const SizedBox(width: 2),
                                      Text('$kids'),
                                      const SizedBox(width: 4),
                                    ],
                                    const Icon(Icons.chevron_left),
                                  ],
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PersonDetailScreen(
                                      state: state,
                                      personId: p.id!,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة شخص'),
      ),
    );
  }
}
DART_EOF

# ───────────────────────── 5) شاشة الشجرة: خطوط أجيال وصور رمزية ─────────────────────────
cat > lib/ui/tree_screen.dart <<'DART_EOF'
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/family_tree_index.dart';
import 'person_detail_screen.dart';
import 'widgets.dart';

class TreeScreen extends StatefulWidget {
  const TreeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends State<TreeScreen> {
  final _controller = TextEditingController();
  String _query = '';
  late final Set<int> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = {
      for (final r in FamilyTreeIndex(widget.state.all).roots) r.id!,
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(int id) {
    setState(() {
      if (!_expanded.remove(id)) {
        _expanded.add(id);
      }
    });
  }

  Widget _row(BuildContext context, TreeRow r, bool searching) {
    final state = widget.state;
    final p = r.person;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final depth = math.min(r.depth, 14);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PersonDetailScreen(state: state, personId: p.id!),
        ),
      ),
      child: Container(
        height: 48,
        padding: const EdgeInsetsDirectional.only(start: 8, end: 10),
        color: r.isMatch ? scheme.primaryContainer.withAlpha(120) : null,
        child: Row(
          children: [
            // خطوط عمودية رفيعة تُظهر عمق الجيل
            for (var d = 0; d < depth; d++)
              Container(
                width: 20,
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    end: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
              ),
            SizedBox(
              width: 36,
              height: 36,
              child: r.hasVisibleChildren
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: r.expanded ? 'إغلاق الفرع' : 'فتح الفرع',
                      icon: Icon(
                        r.expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_left,
                        color: scheme.primary,
                      ),
                      onPressed: searching ? null : () => _toggle(p.id!),
                    )
                  : null,
            ),
            PersonAvatar(gender: p.gender, radius: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.displayName(p),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: r.isMatch
                    ? TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      )
                    : null,
              ),
            ),
            if (r.childCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${r.childCount}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final index = FamilyTreeIndex(widget.state.all);
        final searching = _query.trim().isNotEmpty;
        Set<int>? visible;
        var matches = <int>{};
        if (searching) {
          matches = widget.state.search(_query).map((p) => p.id!).toSet();
          visible = index.withAncestors(matches);
        }
        final rows = index.flatten(
          expanded: _expanded,
          visible: visible,
          matches: matches,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('شجرة النسب'),
            actions: [
              IconButton(
                tooltip: 'فتح كل الفروع',
                icon: const Icon(Icons.unfold_more),
                onPressed: () => setState(() {
                  _expanded
                    ..clear()
                    ..addAll(index.expandableIds);
                }),
              ),
              IconButton(
                tooltip: 'إغلاق كل الفروع',
                icon: const Icon(Icons.unfold_less),
                onPressed: () => setState(_expanded.clear),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'ابحث في الشجرة بالاسم',
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? EmptyState(
                        icon: widget.state.all.isEmpty
                            ? Icons.account_tree_outlined
                            : Icons.search_off,
                        message: widget.state.all.isEmpty
                            ? 'لا يوجد أفراد بعد.'
                            : 'لا نتائج مطابقة',
                      )
                    : ListView.builder(
                        itemCount: rows.length,
                        itemExtent: 48,
                        itemBuilder: (context, i) =>
                            _row(context, rows[i], searching),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
DART_EOF

echo "تم تطبيق تحسين المظهر v2 وإعادة تصميم بطاقة الفرد."
