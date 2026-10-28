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
