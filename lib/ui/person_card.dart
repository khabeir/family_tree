import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/person.dart';
import '../domain/relations.dart';
import 'branding.dart';
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
  Colors.red,
  Colors.orange,
  Colors.purple,
  Colors.blueGrey,
  Colors.brown,
  Colors.indigo,
];

MaterialColor cardAccentFor(Gender g) => switch (g) {
      Gender.male => Colors.blue,
      Gender.female => Colors.pink,
      Gender.unknown => Colors.blueGrey,
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
            Container(
              color: accent.shade700,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const Center(
                child: Text(
                  kCreditText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
