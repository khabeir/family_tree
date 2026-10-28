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
