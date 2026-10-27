import 'package:family_tree/data/models/marriage.dart';
import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/domain/mind_map.dart';
import 'package:flutter_test/flutter_test.dart';

Person p(int id, String name, Gender g, {int? f, int? m}) =>
    Person(id: id, name: name, gender: g, fatherId: f, motherId: m);

Marriage mar(int id, int a, int b, {MarriageStatus s = MarriageStatus.married}) =>
    Marriage(id: id, person1Id: a, person2Id: b, status: s);

List<String> keys(MindNode n) =>
    [n.key, for (final c in n.children) ...keys(c)];

void main() {
  final people = [
    p(1, 'محمد', Gender.male),
    p(2, 'البتول', Gender.female),
    p(3, 'رابعة', Gender.female),
    p(4, 'زينب', Gender.female, f: 1, m: 2),
    p(5, 'الطيب', Gender.male, f: 1, m: 2),
    p(6, 'موسى', Gender.male, f: 1, m: 3),
    p(7, 'زوج زينب', Gender.male),
    p(8, 'مبارك', Gender.male, f: 7, m: 4),
    p(9, 'بلا أم', Gender.male, f: 1),
  ];
  final marriages = [
    mar(1, 1, 2),
    mar(2, 1, 3),
    mar(3, 4, 7),
  ];

  test('الأبناء يتفرعون من عقدة الزواج المطابقة، ومن لا أم له مباشرة', () {
    final root = MindMapBuilder(people, marriages).build(1)!;
    expect(root.key, 'p1');
    expect(root.children.map((c) => c.key), ['m1', 'm2', 'p9']);

    final m1 = root.children[0];
    expect(m1.kind, MindKind.marriage);
    expect(m1.spouse!.id, 2);
    expect(m1.children.map((c) => c.key), ['p4', 'p5']);

    final m2 = root.children[1];
    expect(m2.children.map((c) => c.key), ['p6']);
  });

  test('البنت تتفرع منها عقدة زوجها وأبناؤها', () {
    final root = MindMapBuilder(people, marriages).build(1)!;
    final zainab = root.children[0].children[0];
    expect(zainab.key, 'p4');
    expect(zainab.children.map((c) => c.key), ['m3']);
    final m3 = zainab.children.first;
    expect(m3.spouse!.id, 7);
    expect(m3.children.map((c) => c.key), ['p8']);
  });

  test('شخص غير موجود يعيد null', () {
    expect(MindMapBuilder(people, marriages).build(999), isNull);
  });

  test('كل شخص وكل زواج مرة واحدة حتى مع زواج الأقارب', () {
    final ppl = [
      p(1, 'جد', Gender.male),
      p(2, 'ابن', Gender.male, f: 1),
      p(3, 'بنت', Gender.female, f: 1),
      p(4, 'حفيد', Gender.male, f: 2, m: 3),
    ];
    final root = MindMapBuilder(ppl, [mar(1, 2, 3)]).build(1)!;
    final all = keys(root);
    expect(all.toSet().length, all.length);
    expect(all, containsAll(['p1', 'p2', 'p3', 'p4', 'm1']));
  });

  test('بيانات حلقية لا تُسبّب تكراراً لا نهائياً', () {
    final ppl = [
      p(1, 'أ', Gender.male, f: 2),
      p(2, 'ب', Gender.male, f: 1),
    ];
    final root = MindMapBuilder(ppl, const []).build(1)!;
    expect(keys(root).toSet().length, keys(root).length);
  });

  test('مفاتيح الفتح الابتدائي', () {
    final root = MindMapBuilder(people, marriages).build(1)!;
    expect(keysUpToDepth(root, 1), {'p1'});
    expect(keysUpToDepth(root, 2), {'p1', 'm1', 'm2'});
    expect(allExpandableKeys(root).containsAll({'p1', 'm1', 'p4', 'm3'}), isTrue);
  });

  test('التخطيط: مغلق ثم مفتوح', () {
    final root = MindMapBuilder(people, marriages).build(1)!;

    final closed = layoutMindMap(root, {});
    expect(closed.boxes.length, 1);
    expect(closed.boxes.first.y, 0);

    final one = layoutMindMap(root, {'p1'});
    expect(one.boxes.map((b) => b.node.key), ['p1', 'm1', 'm2', 'p9']);
    expect(one.boxes.map((b) => b.y), [76, 0, 76, 152]);
    expect(one.maxDepth, 1);
    expect(one.edges.length, 3);

    final two = layoutMindMap(root, {'p1', 'm1'});
    expect(two.boxes.map((b) => b.node.key),
        ['p1', 'm1', 'p4', 'p5', 'm2', 'p9']);
    expect(two.boxes.first.y, 133);
    expect(two.maxDepth, 2);
  });
}
