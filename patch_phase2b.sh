#!/usr/bin/env bash
# شجرة عائلتي - تعديل 2ب: عرض الاسم بسلسلة الآباء + إخفاء تاريخي الميلاد والوفاة
# شغّله من جذر المستودع: bash patch_phase2b.sh
set -euo pipefail

# ───────────────────────── AppState ─────────────────────────
cat > lib/app_state.dart <<'DART_EOF'
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'core/arabic_text.dart';
import 'data/models/marriage.dart';
import 'data/models/person.dart';
import 'data/repositories/marriage_repository.dart';
import 'data/repositories/person_repository.dart';
import 'domain/family_service.dart';

/// حالة التطبيق: نسخة مخزنة من الأشخاص في الذاكرة + عمليات الكتابة عبر FamilyService.
///
/// الحقل `name` في قاعدة البيانات هو الاسم الأول فقط. الاسم المعروض يُركَّب
/// تلقائياً بسلسلة الآباء (حتى [maxNameParts] أجزاء).
class AppState extends ChangeNotifier {
  AppState(Database db)
      : persons = PersonRepository(db),
        marriages = MarriageRepository(db) {
    service = FamilyService(persons, marriages);
  }

  static const int maxNameParts = 4;

  final PersonRepository persons;
  final MarriageRepository marriages;
  late final FamilyService service;

  List<Person> _all = const [];
  Map<int, Person> _byId = const {};
  Map<int, String> _display = const {};

  List<Person> get all => _all;

  Person? byId(int? id) => id == null ? null : _byId[id];

  /// الاسم المعروض: الاسم الأول + أسماء الآباء (ثلاثي/رباعي إن وُجدوا).
  String displayName(Person p) => _display[p.id] ?? p.name;

  /// يركّب اسماً من [first] وسلسلة الآباء ابتداءً من [fatherId] (للمعاينة أثناء الإدخال).
  String composeName(String first, int? fatherId, {int? selfId}) {
    final parts = <String>[first.trim()];
    final seen = <int>{if (selfId != null) selfId};
    var next = fatherId;
    while (next != null && parts.length < maxNameParts && seen.add(next)) {
      final father = _byId[next];
      if (father == null) break;
      parts.add(father.name);
      next = father.fatherId;
    }
    return parts.where((s) => s.isNotEmpty).join(' ');
  }

  Future<void> load() async {
    final rows = await persons.getAll();
    _byId = {for (final p in rows) p.id!: p};
    _display = {
      for (final p in rows) p.id!: composeName(p.name, p.fatherId, selfId: p.id),
    };
    rows.sort((a, b) =>
        normalizeArabic(_display[a.id]!).compareTo(normalizeArabic(_display[b.id]!)));
    _all = rows;
    notifyListeners();
  }

  // ───── استعلامات ─────

  List<Person> search(String query) {
    final q = normalizeArabic(query);
    if (q.isEmpty) {
      return _all;
    }
    return _all
        .where((p) => normalizeArabic(displayName(p)).contains(q))
        .toList();
  }

  List<Person> childrenOf(int id) {
    final list =
        _all.where((p) => p.fatherId == id || p.motherId == id).toList();
    list.sort((a, b) {
      final x = a.birthDate;
      final y = b.birthDate;
      if (x != null && y != null && x != y) return x.compareTo(y);
      if (x != null && y == null) return -1;
      if (x == null && y != null) return 1;
      return a.id!.compareTo(b.id!);
    });
    return list;
  }

  String? parentsLabel(Person p) {
    final parts = <String>[];
    final father = byId(p.fatherId);
    final mother = byId(p.motherId);
    if (father != null) parts.add('الأب: ${displayName(father)}');
    if (mother != null) parts.add('الأم: ${displayName(mother)}');
    return parts.isEmpty ? null : parts.join(' • ');
  }

  Future<List<Marriage>> marriagesOf(int personId) =>
      marriages.getForPerson(personId);

  // ───── كتابة ─────

  Future<int> addPerson(Person p) async {
    final id = await service.addPerson(p);
    await load();
    return id;
  }

  Future<bool> updatePerson(Person p) async {
    final ok = await service.updatePerson(p);
    await load();
    return ok;
  }

  Future<bool> deletePerson(int id) async {
    final ok = await service.deletePerson(id);
    await load();
    return ok;
  }

  Future<int> addMarriage(Marriage m) async {
    final id = await service.addMarriage(m);
    notifyListeners();
    return id;
  }

  Future<bool> updateMarriage(Marriage m) async {
    final ok = await service.updateMarriage(m);
    notifyListeners();
    return ok;
  }

  Future<bool> deleteMarriage(int id) async {
    final ok = await service.deleteMarriage(id);
    notifyListeners();
    return ok;
  }
}
DART_EOF

# ───────────────────────── نموذج الشخص (بلا تواريخ) ─────────────────────────
cat > lib/ui/person_form_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/person.dart';
import '../domain/family_service.dart';
import 'person_picker_screen.dart';
import 'ui_helpers.dart';

class PersonFormScreen extends StatefulWidget {
  const PersonFormScreen({
    super.key,
    required this.state,
    this.person,
    this.presetFatherId,
    this.presetMotherId,
  });

  final AppState state;
  final Person? person;
  final int? presetFatherId;
  final int? presetMotherId;

  @override
  State<PersonFormScreen> createState() => _PersonFormScreenState();
}

class _PersonFormScreenState extends State<PersonFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late Gender _gender;
  int? _fatherId;
  int? _motherId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.person;
    _name = TextEditingController(text: p?.name ?? '');
    _notes = TextEditingController(text: p?.notes ?? '');
    _gender = p?.gender ?? Gender.unknown;
    _fatherId = p?.fatherId ?? widget.presetFatherId;
    _motherId = p?.motherId ?? widget.presetMotherId;
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickFather() async {
    final picked = await Navigator.of(context).push<Person>(
      MaterialPageRoute(
        builder: (_) => PersonPickerScreen(
          state: widget.state,
          title: 'اختيار الأب',
          excludeId: widget.person?.id,
          excludeGender: Gender.female,
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _fatherId = picked.id);
  }

  Future<void> _pickMother() async {
    final picked = await Navigator.of(context).push<Person>(
      MaterialPageRoute(
        builder: (_) => PersonPickerScreen(
          state: widget.state,
          title: 'اختيار الأم',
          excludeId: widget.person?.id,
          excludeGender: Gender.male,
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _motherId = picked.id);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final base = widget.person;
    final person = Person(
      id: base?.id,
      name: _name.text,
      gender: _gender,
      fatherId: _fatherId,
      motherId: _motherId,
      birthDate: base?.birthDate,
      deathDate: base?.deathDate,
      notes: _notes.text,
      createdAt: base?.createdAt,
    );
    final ok = await runGuarded(context, () async {
      if (base == null) {
        await widget.state.addPerson(person);
      } else {
        final found = await widget.state.updatePerson(person);
        if (!found) {
          throw FamilyValidationException('الشخص لم يعد موجوداً');
        }
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(true);
  }

  Widget _parentTile({
    required String label,
    required Person? person,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        title: Text(label),
        subtitle:
            Text(person == null ? 'غير محدد' : widget.state.displayName(person)),
        trailing: person == null
            ? const Icon(Icons.chevron_left)
            : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
        onTap: onPick,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.person != null;
    final preview = widget.state
        .composeName(_name.text, _fatherId, selfId: widget.person?.id);
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل شخص' : 'إضافة شخص')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'الاسم الأول',
                helperText: 'اكتب الاسم الأول فقط، وتُضاف أسماء الآباء تلقائياً',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
            ),
            if (_name.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'سيظهر باسم: $preview',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            const SizedBox(height: 16),
            SegmentedButton<Gender>(
              segments: const [
                ButtonSegment(value: Gender.male, label: Text('ذكر')),
                ButtonSegment(value: Gender.female, label: Text('أنثى')),
                ButtonSegment(value: Gender.unknown, label: Text('غير محدد')),
              ],
              selected: {_gender},
              onSelectionChanged: (s) => setState(() => _gender = s.first),
            ),
            const SizedBox(height: 16),
            _parentTile(
              label: 'الأب',
              person: widget.state.byId(_fatherId),
              onPick: _pickFather,
              onClear: () => setState(() => _fatherId = null),
            ),
            const SizedBox(height: 8),
            _parentTile(
              label: 'الأم',
              person: widget.state.byId(_motherId),
              onPick: _pickMother,
              onClear: () => setState(() => _motherId = null),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notes,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save),
              label: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
DART_EOF

# ───────────────────────── تفاصيل الشخص ─────────────────────────
cat > lib/ui/person_detail_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/marriage.dart';
import '../data/models/person.dart';
import 'marriage_form_screen.dart';
import 'person_form_screen.dart';
import 'ui_helpers.dart';

class PersonDetailScreen extends StatelessWidget {
  const PersonDetailScreen({
    super.key,
    required this.state,
    required this.personId,
  });

  final AppState state;
  final int personId;

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

  Widget _header(BuildContext context, String title, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (action != null) action,
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
            appBar: AppBar(),
            body: const Center(child: Text('هذا الشخص غير موجود')),
          );
        }
        final father = state.byId(p.fatherId);
        final mother = state.byId(p.motherId);
        final children = state.childrenOf(personId);

        return Scaffold(
          appBar: AppBar(
            title: Text(state.displayName(p)),
            actions: [
              IconButton(
                tooltip: 'تعديل',
                icon: const Icon(Icons.edit),
                onPressed: () => _edit(context, p),
              ),
              IconButton(
                tooltip: 'حذف',
                icon: const Icon(Icons.delete),
                onPressed: () => _delete(context, p),
              ),
            ],
          ),
          body: ListView(
            children: [
              ListTile(
                leading: Icon(genderIcon(p.gender)),
                title: Text(genderLabel(p.gender)),
              ),
              if (p.notes != null)
                ListTile(
                  leading: const Icon(Icons.notes),
                  title: Text(p.notes!),
                ),
              _header(context, 'الوالدان'),
              if (father == null && mother == null)
                const ListTile(title: Text('غير مسجلين')),
              if (father != null)
                ListTile(
                  title: Text('الأب: ${state.displayName(father)}'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => _open(context, father.id!),
                ),
              if (mother != null)
                ListTile(
                  title: Text('الأم: ${state.displayName(mother)}'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => _open(context, mother.id!),
                ),
              _header(
                context,
                'الزواج',
                action: TextButton.icon(
                  onPressed: () => _marriageForm(context, p),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                ),
              ),
              FutureBuilder<List<Marriage>>(
                future: state.marriagesOf(personId),
                builder: (context, snapshot) {
                  final list = snapshot.data;
                  if (list == null) return const SizedBox.shrink();
                  if (list.isEmpty) {
                    return const ListTile(title: Text('لا توجد علاقات مسجلة'));
                  }
                  return Column(
                    children: [
                      for (final m in list) _marriageTile(context, p, m),
                    ],
                  );
                },
              ),
              _header(
                context,
                'الأبناء (${children.length})',
                action: TextButton.icon(
                  onPressed: () => _addChild(context, p),
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة'),
                ),
              ),
              if (children.isEmpty)
                const ListTile(title: Text('لا يوجد أبناء مسجلون')),
              for (final c in children)
                ListTile(
                  leading: Icon(genderIcon(c.gender)),
                  title: Text(state.displayName(c)),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => _open(context, c.id!),
                ),
              const SizedBox(height: 32),
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
      leading: const Icon(Icons.favorite),
      title: Text(other == null ? 'غير معروف' : state.displayName(other)),
      subtitle: Text(
        [marriageStatusLabel(m.status), if (dates.isNotEmpty) dates].join(' • '),
      ),
      onTap: () => _marriageForm(context, p, m),
      trailing: IconButton(
        tooltip: 'حذف العلاقة',
        icon: const Icon(Icons.delete_outline),
        onPressed: () => _deleteMarriage(context, m),
      ),
    );
  }
}
DART_EOF

# ───────────────────────── تعديلات صغيرة بـ sed (مع تحقق) ─────────────────────────
sed -i "s|title: Text(p.name),|title: Text(state.displayName(p)),|" lib/ui/person_list_screen.dart
grep -q "state.displayName(p)" lib/ui/person_list_screen.dart

sed -i "s|title: Text(p.name),|title: Text(widget.state.displayName(p)),|" lib/ui/person_picker_screen.dart
grep -q "widget.state.displayName(p)" lib/ui/person_picker_screen.dart

sed -i "s|subtitle: Text(spouse?.name ?? 'اضغط للاختيار'),|subtitle: Text(spouse == null ? 'اضغط للاختيار' : widget.state.displayName(spouse)),|" lib/ui/marriage_form_screen.dart
grep -q "widget.state.displayName(spouse)" lib/ui/marriage_form_screen.dart

# ───────────────────────── اختبار AppState (محدّث) ─────────────────────────
cat > test/app_state_test.dart <<'DART_EOF'
import 'package:family_tree/app_state.dart';
import 'package:family_tree/data/models/marriage.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/domain/family_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'support/test_db.dart';

void main() {
  late Database db;
  late AppState state;

  setUp(() async {
    db = await openTestDb();
    state = AppState(db);
    await state.load();
  });

  tearDown(() => db.close());

  test('الإضافة تحدّث القائمة المخزنة وتُشعر المستمعين', () async {
    var notified = 0;
    state.addListener(() => notified++);
    final id = await state.addPerson(const Person(name: 'أحمد'));
    expect(state.all.length, 1);
    expect(state.byId(id)!.name, 'أحمد');
    expect(notified, greaterThan(0));
  });

  test('الاسم المعروض ثلاثي/رباعي بسلسلة الآباء ويتوقف عند 4 أجزاء', () async {
    final g3 = await state
        .addPerson(const Person(name: 'حسن', gender: Gender.male));
    final g2 = await state.addPerson(
        Person(name: 'علي', gender: Gender.male, fatherId: g3));
    final g1 = await state.addPerson(
        Person(name: 'محمد', gender: Gender.male, fatherId: g2));
    final me = await state.addPerson(Person(name: 'أحمد', fatherId: g1));
    final kid = await state.addPerson(Person(name: 'سارة', fatherId: me));

    expect(state.displayName(state.byId(g3)!), 'حسن');
    expect(state.displayName(state.byId(g1)!), 'محمد علي حسن');
    expect(state.displayName(state.byId(me)!), 'أحمد محمد علي حسن');
    // الابن الخامس في السلسلة: 4 أجزاء فقط
    expect(state.displayName(state.byId(kid)!), 'سارة أحمد محمد علي');
  });

  test('تمييز الأسماء المكررة بالآباء المختلفين', () async {
    final f1 = await state
        .addPerson(const Person(name: 'علي', gender: Gender.male));
    final f2 = await state
        .addPerson(const Person(name: 'حسن', gender: Gender.male));
    final a = await state.addPerson(Person(name: 'محمد', fatherId: f1));
    final b = await state.addPerson(Person(name: 'محمد', fatherId: f2));
    expect(state.displayName(state.byId(a)!), 'محمد علي');
    expect(state.displayName(state.byId(b)!), 'محمد حسن');
  });

  test('معاينة الاسم أثناء الإدخال', () async {
    final f = await state
        .addPerson(const Person(name: 'علي', gender: Gender.male));
    expect(state.composeName('  خالد ', f), 'خالد علي');
    expect(state.composeName('خالد', null), 'خالد');
  });

  test('البحث يعمل على الاسم الكامل ويتجاهل الهمزة والتشكيل', () async {
    final f = await state
        .addPerson(const Person(name: 'علي', gender: Gender.male));
    await state.addPerson(Person(name: 'أحمد', fatherId: f));
    await state.addPerson(const Person(name: 'خالد'));
    expect(state.search('احمد').length, 1);
    expect(state.search('احمد علي').length, 1);
    expect(state.search('').length, 3);
    expect(state.search('زيد'), isEmpty);
  });

  test('الأبناء وتسمية الوالدين', () async {
    final f = await state
        .addPerson(const Person(name: 'الأب', gender: Gender.male));
    final m = await state
        .addPerson(const Person(name: 'الأم', gender: Gender.female));
    final c1 = await state.addPerson(Person(name: 'ب', fatherId: f, motherId: m));
    await state.addPerson(Person(name: 'أ', fatherId: f));
    expect(state.childrenOf(f).length, 2);
    expect(state.parentsLabel(state.byId(c1)!), 'الأب: الأب • الأم: الأم');
  });

  test('الحذف يفرّغ الوالد عند الابن ويحدّث الحالة', () async {
    final f = await state
        .addPerson(const Person(name: 'الأب', gender: Gender.male));
    final c = await state.addPerson(Person(name: 'ابن', fatherId: f));
    expect(await state.deletePerson(f), isTrue);
    expect(state.byId(f), isNull);
    expect(state.byId(c)!.fatherId, isNull);
    expect(state.displayName(state.byId(c)!), 'ابن');
  });

  test('أخطاء التحقق تنتقل للواجهة ولا تغيّر الحالة', () async {
    await expectLater(state.addPerson(const Person(name: '')),
        throwsA(isA<FamilyValidationException>()));
    expect(state.all, isEmpty);
  });

  test('الزواج عبر الحالة', () async {
    final a = await state.addPerson(const Person(name: 'أ'));
    final b = await state.addPerson(const Person(name: 'ب'));
    final id = await state.addMarriage(Marriage(person1Id: a, person2Id: b));
    expect((await state.marriagesOf(a)).length, 1);
    expect(await state.deleteMarriage(id), isTrue);
    expect(await state.marriagesOf(a), isEmpty);
  });
}
DART_EOF

echo "تم تطبيق التعديل 2ب."
