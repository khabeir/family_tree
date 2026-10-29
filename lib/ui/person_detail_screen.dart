import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/marriage.dart';
import '../data/models/person.dart';
import '../domain/relations.dart';
import 'marriage_form_screen.dart';
import 'mind_map_screen.dart';
import 'person_form_screen.dart';
import 'person_card_screen.dart';
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

  Widget _stat(BuildContext context, String label, int value) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: scheme.onPrimaryContainer,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onPrimaryContainer.withAlpha(190),
            ),
          ),
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
    final parents = state.parentsLabel(p);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Colors.blue.shade700, Colors.blue.shade400],
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
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    child: Icon(genderIcon(p.gender), size: 44),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  state.displayName(p),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                if (parents != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    parents,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
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
          Container(
            color: scheme.primaryContainer,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                _stat(context, 'الأبناء', kids),
                _stat(context, 'الزواج', spouses),
                _stat(context, 'الإخوة', sibs),
              ],
            ),
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
              IconButton(
                tooltip: 'حفظ كصورة',
                icon: const Icon(Icons.save_alt),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PersonCardScreen(state: state, personId: personId),
                  ),
                ),
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
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PersonCardScreen(state: state, personId: personId),
                        ),
                      ),
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('حفظ كصورة'),
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
