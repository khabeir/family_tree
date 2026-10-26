#!/usr/bin/env bash
# شجرة عائلتي - المرحلة 2: الواجهات
# شغّله من جذر المستودع بعد نجاح المرحلة 1: bash setup_phase2.sh
set -euo pipefail

mkdir -p lib/core lib/ui test

# في CI: لا نفشل البناء بسبب تنبيهات info فقط (تبقى warnings وerrors فاشلة)
sed -i 's/- run: flutter analyze$/- run: flutter analyze --no-fatal-infos/' .github/workflows/build.yml

# ───────────────────────── نص عربي ─────────────────────────
cat > lib/core/arabic_text.dart <<'DART_EOF'
/// توحيد النص العربي للبحث: إزالة التشكيل والتطويل، وتوحيد الهمزات والتاء المربوطة والألف المقصورة.
String normalizeArabic(String input) {
  var s = input.toLowerCase();
  s = s.replaceAll(RegExp('[\u064B-\u065F\u0670\u0640]'), '');
  s = s.replaceAll(RegExp('[\u0623\u0625\u0622\u0671]'), '\u0627');
  s = s.replaceAll('\u0629', '\u0647');
  s = s.replaceAll('\u0649', '\u064A');
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  return s.trim();
}
DART_EOF

# ───────────────────────── حالة التطبيق ─────────────────────────
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
class AppState extends ChangeNotifier {
  AppState(Database db)
      : persons = PersonRepository(db),
        marriages = MarriageRepository(db) {
    service = FamilyService(persons, marriages);
  }

  final PersonRepository persons;
  final MarriageRepository marriages;
  late final FamilyService service;

  List<Person> _all = const [];
  Map<int, Person> _byId = const {};

  List<Person> get all => _all;

  Person? byId(int? id) => id == null ? null : _byId[id];

  Future<void> load() async {
    _all = await persons.getAll();
    _byId = {for (final p in _all) p.id!: p};
    notifyListeners();
  }

  // ───── استعلامات ─────

  List<Person> search(String query) {
    final q = normalizeArabic(query);
    if (q.isEmpty) {
      return _all;
    }
    return _all.where((p) => normalizeArabic(p.name).contains(q)).toList();
  }

  List<Person> childrenOf(int id) {
    final list =
        _all.where((p) => p.fatherId == id || p.motherId == id).toList();
    list.sort((a, b) {
      final x = a.birthDate;
      final y = b.birthDate;
      if (x == null && y == null) return a.name.compareTo(b.name);
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
    return list;
  }

  String? parentsLabel(Person p) {
    final parts = <String>[];
    final father = byId(p.fatherId);
    final mother = byId(p.motherId);
    if (father != null) parts.add('الأب: ${father.name}');
    if (mother != null) parts.add('الأم: ${mother.name}');
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

# ───────────────────────── main ─────────────────────────
cat > lib/main.dart <<'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'data/database/app_database.dart';
import 'ui/person_list_screen.dart';

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
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: PersonListScreen(state: state),
    );
  }
}
DART_EOF

# ───────────────────────── مساعدات الواجهة ─────────────────────────
cat > lib/ui/ui_helpers.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../data/models/marriage.dart';
import '../data/models/person.dart';
import '../domain/family_service.dart';

String genderLabel(Gender g) => switch (g) {
      Gender.male => 'ذكر',
      Gender.female => 'أنثى',
      Gender.unknown => 'غير محدد',
    };

String marriageStatusLabel(MarriageStatus s) => switch (s) {
      MarriageStatus.married => 'قائم',
      MarriageStatus.divorced => 'انتهى بطلاق',
      MarriageStatus.widowed => 'انتهى بوفاة',
    };

IconData genderIcon(Gender g) => switch (g) {
      Gender.male => Icons.man,
      Gender.female => Icons.woman,
      Gender.unknown => Icons.person,
    };

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'تأكيد',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// ينفذ [action] ويعرض أخطاء التحقق للمستخدم. يعيد true عند النجاح.
Future<bool> runGuarded(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } on FamilyValidationException catch (e) {
    showMessage(context, e.message);
  } catch (e) {
    showMessage(context, 'تعذّر تنفيذ العملية: $e');
  }
  return false;
}
DART_EOF

cat > lib/ui/date_field.dart <<'DART_EOF'
import 'package:flutter/material.dart';

String formatIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  Future<void> _pick(BuildContext context) async {
    final initial =
        (value == null ? null : DateTime.tryParse(value!)) ?? DateTime(1980);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onChanged(formatIsoDate(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? const Icon(Icons.calendar_today)
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null),
                ),
        ),
        child: Text(value ?? 'غير محدد'),
      ),
    );
  }
}
DART_EOF

# ───────────────────────── اختيار شخص ─────────────────────────
cat > lib/ui/person_picker_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/person.dart';
import 'ui_helpers.dart';

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
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث بالاسم',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('لا نتائج'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final p = items[i];
                      return ListTile(
                        leading: Icon(genderIcon(p.gender)),
                        title: Text(p.name),
                        subtitle: widget.state.parentsLabel(p) == null
                            ? null
                            : Text(widget.state.parentsLabel(p)!),
                        onTap: () => Navigator.of(context).pop(p),
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

# ───────────────────────── القائمة ─────────────────────────
cat > lib/ui/person_list_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import 'person_detail_screen.dart';
import 'person_form_screen.dart';
import 'ui_helpers.dart';

class PersonListScreen extends StatefulWidget {
  const PersonListScreen({super.key, required this.state});

  final AppState state;

  @override
  State<PersonListScreen> createState() => _PersonListScreenState();
}

class _PersonListScreenState extends State<PersonListScreen> {
  final _controller = TextEditingController();
  String _query = '';

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

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: state,
          builder: (context, _) => Text('شجرة عائلتي (${state.all.length})'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'ابحث بالاسم',
                border: const OutlineInputBorder(),
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
            child: ListenableBuilder(
              listenable: state,
              builder: (context, _) {
                final items = state.search(_query);
                if (items.isEmpty) {
                  return Center(
                    child: Text(state.all.isEmpty
                        ? 'لا يوجد أفراد بعد. اضغط «إضافة شخص».'
                        : 'لا نتائج مطابقة'),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final p = items[i];
                    final parents = state.parentsLabel(p);
                    return ListTile(
                      leading: CircleAvatar(child: Icon(genderIcon(p.gender))),
                      title: Text(p.name),
                      subtitle: parents == null ? null : Text(parents),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PersonDetailScreen(
                            state: state,
                            personId: p.id!,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
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

# ───────────────────────── نموذج الشخص ─────────────────────────
cat > lib/ui/person_form_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/person.dart';
import '../domain/family_service.dart';
import 'date_field.dart';
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
  String? _birth;
  String? _death;
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
    _birth = p?.birthDate;
    _death = p?.deathDate;
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
      birthDate: _birth,
      deathDate: _death,
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
        subtitle: Text(person?.name ?? 'غير محدد'),
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
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل شخص' : 'إضافة شخص')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
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
            DateField(
              label: 'تاريخ الميلاد',
              value: _birth,
              onChanged: (v) => setState(() => _birth = v),
            ),
            const SizedBox(height: 16),
            DateField(
              label: 'تاريخ الوفاة',
              value: _death,
              onChanged: (v) => setState(() => _death = v),
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

# ───────────────────────── نموذج الزواج ─────────────────────────
cat > lib/ui/marriage_form_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/marriage.dart';
import '../data/models/person.dart';
import '../domain/family_service.dart';
import 'date_field.dart';
import 'person_picker_screen.dart';
import 'ui_helpers.dart';

class MarriageFormScreen extends StatefulWidget {
  const MarriageFormScreen({
    super.key,
    required this.state,
    required this.personId,
    this.marriage,
  });

  final AppState state;
  final int personId;
  final Marriage? marriage;

  @override
  State<MarriageFormScreen> createState() => _MarriageFormScreenState();
}

class _MarriageFormScreenState extends State<MarriageFormScreen> {
  late final TextEditingController _notes;
  int? _spouseId;
  late MarriageStatus _status;
  String? _start;
  String? _end;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.marriage;
    _notes = TextEditingController(text: m?.notes ?? '');
    _status = m?.status ?? MarriageStatus.married;
    _start = m?.startDate;
    _end = m?.endDate;
    if (m != null) {
      _spouseId = m.person1Id == widget.personId ? m.person2Id : m.person1Id;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickSpouse() async {
    final picked = await Navigator.of(context).push<Person>(
      MaterialPageRoute(
        builder: (_) => PersonPickerScreen(
          state: widget.state,
          title: 'اختيار الزوج/الزوجة',
          excludeId: widget.personId,
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _spouseId = picked.id);
  }

  Future<void> _save() async {
    final spouseId = _spouseId;
    if (spouseId == null) {
      showMessage(context, 'اختر الزوج/الزوجة أولاً');
      return;
    }
    setState(() => _saving = true);
    final base = widget.marriage;
    final notes = _notes.text.trim();
    final marriage = Marriage(
      id: base?.id,
      person1Id: base?.person1Id ?? widget.personId,
      person2Id: base?.person2Id ?? spouseId,
      startDate: _start,
      endDate: _end,
      status: _status,
      notes: notes.isEmpty ? null : notes,
      createdAt: base?.createdAt,
    );
    final ok = await runGuarded(context, () async {
      if (base == null) {
        await widget.state.addMarriage(marriage);
      } else {
        final found = await widget.state.updateMarriage(marriage);
        if (!found) {
          throw FamilyValidationException('العلاقة لم تعد موجودة');
        }
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.marriage != null;
    final spouse = widget.state.byId(_spouseId);
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل الزواج' : 'إضافة زواج')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              title: const Text('الزوج/الزوجة'),
              subtitle: Text(spouse?.name ?? 'اضغط للاختيار'),
              trailing: isEdit ? null : const Icon(Icons.chevron_left),
              onTap: isEdit ? null : _pickSpouse,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<MarriageStatus>(
            value: _status,
            decoration: const InputDecoration(
              labelText: 'الحالة',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final s in MarriageStatus.values)
                DropdownMenuItem(value: s, child: Text(marriageStatusLabel(s))),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _status = v);
            },
          ),
          const SizedBox(height: 16),
          DateField(
            label: 'تاريخ الزواج',
            value: _start,
            onChanged: (v) => setState(() => _start = v),
          ),
          const SizedBox(height: 16),
          DateField(
            label: 'تاريخ الانتهاء',
            value: _end,
            onChanged: (v) => setState(() => _end = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            maxLines: 3,
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
      title: 'حذف ${p.name}؟',
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
            title: Text(p.name),
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
              if (p.birthDate != null)
                ListTile(
                  leading: const Icon(Icons.cake),
                  title: Text('الميلاد: ${p.birthDate}'),
                ),
              if (p.deathDate != null)
                ListTile(
                  leading: const Icon(Icons.event),
                  title: Text('الوفاة: ${p.deathDate}'),
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
                  title: Text('الأب: ${father.name}'),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => _open(context, father.id!),
                ),
              if (mother != null)
                ListTile(
                  title: Text('الأم: ${mother.name}'),
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
                      for (final m in list)
                        _marriageTile(context, p, m),
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
                  title: Text(c.name),
                  subtitle: c.birthDate == null ? null : Text(c.birthDate!),
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
      title: Text(other?.name ?? 'غير معروف'),
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

# ───────────────────────── اختبارات ─────────────────────────
cat > test/arabic_text_test.dart <<'DART_EOF'
import 'package:family_tree/core/arabic_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('يوحّد الهمزات والتاء المربوطة والتشكيل', () {
    expect(normalizeArabic('أَحمد'), normalizeArabic('احمد'));
    expect(normalizeArabic('إبراهيم'), normalizeArabic('ابراهيم'));
    expect(normalizeArabic('فاطمة'), normalizeArabic('فاطمه'));
    expect(normalizeArabic('موسى'), normalizeArabic('موسي'));
  });

  test('يضغط المسافات ويقصّ الأطراف', () {
    expect(normalizeArabic('  محمد    علي '), 'محمد علي');
  });
}
DART_EOF

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

  test('البحث يتجاهل فروق الهمزة والتشكيل', () async {
    await state.addPerson(const Person(name: 'أحمد علي'));
    await state.addPerson(const Person(name: 'خالد'));
    expect(state.search('احمد').length, 1);
    expect(state.search('').length, 2);
    expect(state.search('زيد'), isEmpty);
  });

  test('الأبناء وتسمية الوالدين', () async {
    final f = await state
        .addPerson(const Person(name: 'الأب', gender: Gender.male));
    final m = await state
        .addPerson(const Person(name: 'الأم', gender: Gender.female));
    final c1 = await state.addPerson(
        Person(name: 'ب', fatherId: f, motherId: m, birthDate: '2010-01-01'));
    await state.addPerson(
        Person(name: 'أ', fatherId: f, birthDate: '2005-01-01'));
    final kids = state.childrenOf(f);
    expect(kids.map((e) => e.name).toList(), ['أ', 'ب']);
    expect(state.parentsLabel(state.byId(c1)!), 'الأب: الأب • الأم: الأم');
  });

  test('الحذف يفرّغ الوالد عند الابن ويحدّث الحالة', () async {
    final f = await state
        .addPerson(const Person(name: 'الأب', gender: Gender.male));
    final c = await state.addPerson(Person(name: 'ابن', fatherId: f));
    expect(await state.deletePerson(f), isTrue);
    expect(state.byId(f), isNull);
    expect(state.byId(c)!.fatherId, isNull);
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

echo "تم إنشاء ملفات المرحلة 2."
