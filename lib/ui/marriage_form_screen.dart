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
