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
