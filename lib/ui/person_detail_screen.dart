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
