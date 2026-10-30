import 'package:flutter/material.dart';

import '../app_state.dart';
import '../core/arabic_text.dart';
import '../data/models/person.dart';
import '../domain/family_service.dart';
import 'access_gate.dart';
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
    final fullName = widget.state
        .composeName(person.name, person.fatherId, selfId: base?.id);
    final nameChanged = base == null ||
        base.name != person.name.trim().replaceAll(RegExp(r'\s+'), ' ') ||
        base.fatherId != person.fatherId;
    final duplicate = widget.state.all.any((o) =>
        o.id != base?.id &&
        normalizeArabic(widget.state.displayName(o)) == normalizeArabic(fullName));
    if (nameChanged && duplicate) {
      final go = await confirmDialog(
        context,
        title: 'اسم مكرر',
        message: 'يوجد شخص بالاسم الكامل نفسه: ' + fullName + '. هل تريد المتابعة؟',
        confirmLabel: 'متابعة',
      );
      if (!go || !mounted) {
        if (mounted) setState(() => _saving = false);
        return;
      }
    }

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
    final form = _buildForm(context);
    return widget.person == null ? Gated(child: form) : form;
  }

  Widget _buildForm(BuildContext context) {
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
