#!/usr/bin/env bash
# شجرة عائلتي - تحسينات الواجهات v1: زر الرئيسية + تفاصيل الشخص + قائمة الأفراد + سمة موحّدة
# شغّله من جذر المستودع: bash patch_ui_v1.sh
set -euo pipefail

for f in lib/ui/backup_screen.dart lib/ui/import_screen.dart lib/ui/mind_map_screen.dart \
         lib/ui/marriage_form_screen.dart lib/ui/person_form_screen.dart lib/ui/home_screen.dart; do
  test -f "$f" || { echo "ملف ناقص: $f (طبّق المراحل السابقة أولاً)"; exit 1; }
done
grep -q "allMarriages" lib/app_state.dart || { echo "يلزم تطبيق المرحلة 3ب (الخريطة) أولاً"; exit 1; }

mkdir -p lib/ui lib/domain test

# ───────────────────────── 1) علاقات القرابة (Dart صرف) ─────────────────────────
cat > lib/domain/relations.dart <<'DART_EOF'
import '../data/models/person.dart';

enum SiblingKind { full, paternal, maternal }

class Sibling {
  const Sibling(this.person, this.kind);

  final Person person;
  final SiblingKind kind;
}

/// الإخوة والأخوات: الأشقاء أولاً ثم لأب ثم لأم.
List<Sibling> siblingsOf(List<Person> all, Person p) {
  final result = <Sibling>[];
  for (final o in all) {
    if (o.id == p.id) continue;
    final sameFather = p.fatherId != null && o.fatherId == p.fatherId;
    final sameMother = p.motherId != null && o.motherId == p.motherId;
    if (sameFather && sameMother) {
      result.add(Sibling(o, SiblingKind.full));
    } else if (sameFather) {
      result.add(Sibling(o, SiblingKind.paternal));
    } else if (sameMother) {
      result.add(Sibling(o, SiblingKind.maternal));
    }
  }
  result.sort((a, b) {
    final k = a.kind.index.compareTo(b.kind.index);
    return k != 0 ? k : a.person.id!.compareTo(b.person.id!);
  });
  return result;
}

String siblingLabel(Sibling s) {
  final g = s.person.gender;
  final male = g == Gender.male;
  final female = g == Gender.female;
  switch (s.kind) {
    case SiblingKind.full:
      return male ? 'شقيق' : (female ? 'شقيقة' : 'شقيق/شقيقة');
    case SiblingKind.paternal:
      return male ? 'أخ لأب' : (female ? 'أخت لأب' : 'أخ/أخت لأب');
    case SiblingKind.maternal:
      return male ? 'أخ لأم' : (female ? 'أخت لأم' : 'أخ/أخت لأم');
  }
}

/// سلسلة الآباء صعوداً (الأب ثم الجد ...) دون الشخص نفسه، مع حماية من الحلقات.
List<Person> paternalChain(
  Person? Function(int id) byId,
  Person p, {
  int max = 40,
}) {
  final result = <Person>[];
  final seen = <int>{if (p.id != null) p.id!};
  var cur = p;
  while (result.length < max) {
    final fid = cur.fatherId;
    if (fid == null || !seen.add(fid)) break;
    final father = byId(fid);
    if (father == null) break;
    result.add(father);
    cur = father;
  }
  return result;
}
DART_EOF

# ───────────────────────── 2) عناصر واجهة مشتركة ─────────────────────────
cat > lib/ui/widgets.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../data/models/person.dart';
import 'ui_helpers.dart';

/// صورة رمزية حسب الجنس (بلا صور شخصية في هذه النسخة).
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.gender, this.radius = 20});

  final Gender gender;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (gender) {
      Gender.male => (Colors.blue.shade100, Colors.blue.shade800),
      Gender.female => (Colors.pink.shade100, Colors.pink.shade800),
      Gender.unknown => (Colors.blueGrey.shade100, Colors.blueGrey.shade700),
    };
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      foregroundColor: fg,
      child: Icon(genderIcon(gender), size: radius * 1.15),
    );
  }
}

/// بطاقة قسم بعنوان وأيقونة وزر اختياري.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
DART_EOF

# ───────────────────────── 3) السمة الموحّدة ─────────────────────────
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

class FamilyTreeApp extends StatelessWidget {
  const FamilyTreeApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32));
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
      theme: ThemeData(
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
      ),
      home: HomeScreen(state: state),
    );
  }
}
DART_EOF

# ───────────────────────── 4) تفاصيل الشخص (مع زر الرئيسية) ─────────────────────────
cat > lib/ui/person_detail_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/marriage.dart';
import '../data/models/person.dart';
import '../domain/relations.dart';
import 'marriage_form_screen.dart';
import 'mind_map_screen.dart';
import 'person_form_screen.dart';
import 'ui_helpers.dart';
import 'widgets.dart';

class PersonDetailScreen extends StatelessWidget {
  const PersonDetailScreen({
    super.key,
    required this.state,
    required this.personId,
  });

  final AppState state;
  final int personId;

  /// يعود إلى الشاشة الرئيسية مهما كان عمق التنقل بين الأشخاص.
  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _open(BuildContext context, int id) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonDetailScreen(state: state, personId: id),
      ),
    );
  }

  Future<void> _edit(BuildContext context, Person p) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PersonFormScreen(state: state, person: p),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Person p) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف ${state.displayName(p)}؟',
      message: 'سيُحذف الشخص وعلاقات زواجه، وسيُفرَّغ حقل الأب/الأم عند أبنائه. '
          'لا يمكن التراجع.',
      confirmLabel: 'حذف',
    );
    if (!ok || !context.mounted) return;
    final done = await runGuarded(context, () async {
      await state.deletePerson(p.id!);
    });
    if (done && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _addChild(BuildContext context, Person p) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PersonFormScreen(
          state: state,
          presetFatherId: p.gender == Gender.male ? p.id : null,
          presetMotherId: p.gender == Gender.female ? p.id : null,
        ),
      ),
    );
  }

  Future<void> _marriageForm(BuildContext context, Person p,
      [Marriage? marriage]) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MarriageFormScreen(
          state: state,
          personId: p.id!,
          marriage: marriage,
        ),
      ),
    );
  }

  Future<void> _deleteMarriage(BuildContext context, Marriage m) async {
    final ok = await confirmDialog(
      context,
      title: 'حذف علاقة الزواج؟',
      message: 'لن يتأثر الأشخاص أنفسهم، تُحذف العلاقة فقط.',
      confirmLabel: 'حذف',
    );
    if (!ok || !context.mounted) return;
    await runGuarded(context, () async {
      await state.deleteMarriage(m.id!);
    });
  }

  void _openMindMap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MindMapScreen(state: state, initialRootId: personId),
      ),
    );
  }

  Widget _personTile(
    BuildContext context,
    Person p, {
    String? extra,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: PersonAvatar(gender: p.gender),
      title: Text(state.displayName(p)),
      subtitle: extra == null ? null : Text(extra),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => _open(context, p.id!),
    );
  }

  Widget _stat(BuildContext context, IconData icon, String label, int value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xBFFFFFFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(height: 2),
          Text('$value',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context,
    Person p, {
    required int kids,
    required int spouses,
    required int sibs,
  }) {
    final MaterialColor color = switch (p.gender) {
      Gender.male => Colors.blue,
      Gender.female => Colors.pink,
      Gender.unknown => Colors.blueGrey,
    };
    final parents = state.parentsLabel(p);
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [color.shade50, color.shade100],
        ),
      ),
      child: Column(
        children: [
          PersonAvatar(gender: p.gender, radius: 38),
          const SizedBox(height: 10),
          Text(
            state.displayName(p),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            genderLabel(p.gender),
            style: theme.textTheme.bodyMedium?.copyWith(color: color.shade800),
          ),
          if (parents != null) ...[
            const SizedBox(height: 2),
            Text(parents,
                textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _stat(context, Icons.child_care, 'الأبناء', kids),
              _stat(context, Icons.favorite_border, 'الزواج', spouses),
              _stat(context, Icons.people_outline, 'الإخوة', sibs),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final p = state.byId(personId);
        if (p == null) {
          return Scaffold(
            appBar: AppBar(
              actions: [
                IconButton(
                  tooltip: 'الرئيسية',
                  icon: const Icon(Icons.home_outlined),
                  onPressed: () => _goHome(context),
                ),
              ],
            ),
            body: const EmptyState(
              icon: Icons.person_off_outlined,
              message: 'هذا الشخص غير موجود',
            ),
          );
        }

        final father = state.byId(p.fatherId);
        final mother = state.byId(p.motherId);
        final children = state.childrenOf(personId);
        final marriages = state.allMarriages
            .where((m) => m.person1Id == personId || m.person2Id == personId)
            .toList()
          ..sort((a, b) => a.id!.compareTo(b.id!));
        final siblings = siblingsOf(state.all, p);
        final chain = paternalChain((id) => state.byId(id), p);

        return Scaffold(
          appBar: AppBar(
            title: Text(p.name),
            actions: [
              IconButton(
                tooltip: 'الرئيسية',
                icon: const Icon(Icons.home_outlined),
                onPressed: () => _goHome(context),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') {
                    _edit(context, p);
                  } else if (v == 'delete') {
                    _delete(context, p);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              _header(
                context,
                p,
                kids: children.length,
                spouses: marriages.length,
                sibs: siblings.length,
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () => _addChild(context, p),
                      icon: const Icon(Icons.child_care),
                      label: const Text('إضافة ابن/ابنة'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _marriageForm(context, p),
                      icon: const Icon(Icons.favorite_border),
                      label: const Text('إضافة زواج'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _openMindMap(context),
                      icon: const Icon(Icons.hub),
                      label: const Text('الخريطة الذهنية'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _edit(context, p),
                      icon: const Icon(Icons.edit),
                      label: const Text('تعديل'),
                    ),
                  ],
                ),
              ),
              if (chain.isNotEmpty)
                SectionCard(
                  title: 'سلسلة النسب',
                  icon: Icons.timeline,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(label: Text(p.name)),
                          for (final a in chain) ...[
                            const Icon(Icons.chevron_left, size: 18),
                            ActionChip(
                              label: Text(a.name),
                              onPressed: () => _open(context, a.id!),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              SectionCard(
                title: 'الوالدان',
                icon: Icons.family_restroom,
                children: [
                  if (father == null && mother == null)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('غير مسجلين'),
                    ),
                  if (father != null)
                    _personTile(context, father, extra: 'الأب'),
                  if (mother != null)
                    _personTile(context, mother, extra: 'الأم'),
                ],
              ),
              SectionCard(
                title: 'الزواج (${marriages.length})',
                icon: Icons.favorite,
                trailing: TextButton.icon(
                  onPressed: () => _marriageForm(context, p),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                ),
                children: [
                  if (marriages.isEmpty)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('لا توجد علاقات مسجلة'),
                    ),
                  for (final m in marriages) _marriageTile(context, p, m),
                ],
              ),
              SectionCard(
                title: 'الأبناء (${children.length})',
                icon: Icons.child_care,
                trailing: TextButton.icon(
                  onPressed: () => _addChild(context, p),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                ),
                children: [
                  if (children.isEmpty)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('لا يوجد أبناء مسجلون'),
                    ),
                  for (final c in children) _personTile(context, c),
                ],
              ),
              if (siblings.isNotEmpty)
                SectionCard(
                  title: 'الإخوة والأخوات (${siblings.length})',
                  icon: Icons.people_outline,
                  children: [
                    for (final s in siblings)
                      _personTile(context, s.person, extra: siblingLabel(s)),
                  ],
                ),
              if (p.notes != null)
                SectionCard(
                  title: 'ملاحظات',
                  icon: Icons.notes,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(p.notes!),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _marriageTile(BuildContext context, Person p, Marriage m) {
    final otherId = m.person1Id == p.id ? m.person2Id : m.person1Id;
    final other = state.byId(otherId);
    final dates = [
      if (m.startDate != null) 'من ${m.startDate}',
      if (m.endDate != null) 'إلى ${m.endDate}',
    ].join(' ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: PersonAvatar(gender: other?.gender ?? Gender.unknown),
      title: Text(other == null ? 'غير معروف' : state.displayName(other)),
      subtitle: Text(
        [marriageStatusLabel(m.status), if (dates.isNotEmpty) dates].join(' • '),
      ),
      onTap: () => _marriageForm(context, p, m),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (other != null)
            IconButton(
              tooltip: 'فتح الشخص',
              icon: const Icon(Icons.person_outline),
              onPressed: () => _open(context, other.id!),
            ),
          IconButton(
            tooltip: 'حذف العلاقة',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteMarriage(context, m),
          ),
        ],
      ),
    );
  }
}
DART_EOF

# ───────────────────────── 5) قائمة الأفراد ─────────────────────────
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

  Widget _stat(BuildContext context, IconData icon, String label, int value,
      Color color) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            Text('$value',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _stat(context, Icons.groups, 'الأفراد', all.length,
                          Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(context, Icons.man, 'ذكور', males,
                          Colors.blue.shade700),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(context, Icons.woman, 'إناث', females,
                          Colors.pink.shade600),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(context, Icons.favorite, 'الزيجات',
                          state.allMarriages.length, Colors.red.shade400),
                    ),
                  ],
                ),
              ),
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

# ───────────────────────── 6) شاشة اختيار الشخص ─────────────────────────
cat > lib/ui/person_picker_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/person.dart';
import 'widgets.dart';

class PersonPickerScreen extends StatefulWidget {
  const PersonPickerScreen({
    super.key,
    required this.state,
    required this.title,
    this.excludeId,
    this.excludeGender,
  });

  final AppState state;
  final String title;
  final int? excludeId;
  final Gender? excludeGender;

  @override
  State<PersonPickerScreen> createState() => _PersonPickerScreenState();
}

class _PersonPickerScreenState extends State<PersonPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final items = widget.state
        .search(_query)
        .where((p) =>
            p.id != widget.excludeId &&
            (widget.excludeGender == null || p.gender != widget.excludeGender))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'ابحث بالاسم',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(icon: Icons.search_off, message: 'لا نتائج')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final p = items[i];
                      final parents = widget.state.parentsLabel(p);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Card(
                          child: ListTile(
                            leading: PersonAvatar(gender: p.gender),
                            title: Text(widget.state.displayName(p)),
                            subtitle: parents == null ? null : Text(parents),
                            onTap: () => Navigator.of(context).pop(p),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
DART_EOF

# ───────────────────────── 7) اختبارات ─────────────────────────
cat > test/relations_test.dart <<'DART_EOF'
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/domain/relations.dart';
import 'package:flutter_test/flutter_test.dart';

Person p(int id, String name, Gender g, {int? f, int? m}) =>
    Person(id: id, name: name, gender: g, fatherId: f, motherId: m);

void main() {
  final all = [
    p(1, 'الأب', Gender.male),
    p(2, 'الأم', Gender.female),
    p(9, 'أم ثانية', Gender.female),
    p(3, 'أنا', Gender.male, f: 1, m: 2),
    p(4, 'شقيقة', Gender.female, f: 1, m: 2),
    p(5, 'أخ لأب', Gender.male, f: 1, m: 9),
    p(6, 'أخت لأم', Gender.female, f: 8, m: 2),
    p(7, 'غريب', Gender.male, f: 8, m: 9),
  ];

  test('الإخوة مرتبون: أشقاء ثم لأب ثم لأم، ويستبعد الغرباء ونفسه', () {
    final me = all.firstWhere((x) => x.id == 3);
    final sibs = siblingsOf(all, me);
    expect(sibs.map((s) => s.person.id), [4, 5, 6]);
    expect(sibs.map((s) => s.kind),
        [SiblingKind.full, SiblingKind.paternal, SiblingKind.maternal]);
  });

  test('تسمية القرابة بحسب الجنس', () {
    expect(siblingLabel(const Sibling(Person(id: 1, name: 'س', gender: Gender.male), SiblingKind.full)), 'شقيق');
    expect(siblingLabel(const Sibling(Person(id: 1, name: 'س', gender: Gender.female), SiblingKind.full)), 'شقيقة');
    expect(siblingLabel(const Sibling(Person(id: 1, name: 'س', gender: Gender.male), SiblingKind.paternal)), 'أخ لأب');
    expect(siblingLabel(const Sibling(Person(id: 1, name: 'س', gender: Gender.female), SiblingKind.maternal)), 'أخت لأم');
    expect(siblingLabel(const Sibling(Person(id: 1, name: 'س', gender: Gender.unknown), SiblingKind.paternal)), 'أخ/أخت لأب');
  });

  test('لا إخوة إن لم يكن للشخص والدان', () {
    final loner = p(10, 'وحيد', Gender.male);
    expect(siblingsOf([...all, loner], loner), isEmpty);
  });

  test('سلسلة الآباء صعوداً', () {
    final byId = {
      for (final x in [
        p(1, 'جد', Gender.male),
        p(2, 'أب', Gender.male, f: 1),
        p(3, 'ابن', Gender.male, f: 2),
      ])
        x.id!: x,
    };
    final chain = paternalChain((id) => byId[id], byId[3]!);
    expect(chain.map((e) => e.name), ['أب', 'جد']);
    expect(paternalChain((id) => byId[id], byId[1]!), isEmpty);
  });

  test('حماية من الحلقات', () {
    final a = p(1, 'أ', Gender.male, f: 2);
    final b = p(2, 'ب', Gender.male, f: 1);
    final byId = {1: a, 2: b};
    final chain = paternalChain((id) => byId[id], a);
    expect(chain.length, 1);
  });
}
DART_EOF

echo "تم تطبيق تحسينات الواجهات v1."
