import 'package:family_tree/data/models/person.dart';
import 'package:family_tree/domain/family_tree_index.dart';
import 'package:flutter_test/flutter_test.dart';

Person p(int id, String name, {int? f, int? m}) =>
    Person(id: id, name: name, fatherId: f, motherId: m);

void main() {
  // 1 جد ── 2 أب ── 4 ابن (أمه 5)
  //      └─ 3 عم
  // 5 أم (جذر) ── 6 يتيم الأب (أمه 5 ولا أب)
  final people = [
    p(1, 'جد'),
    p(2, 'أب', f: 1),
    p(3, 'عم', f: 1),
    p(4, 'ابن', f: 2, m: 5),
    p(5, 'أم'),
    p(6, 'ابن أم', m: 5),
  ];
  late FamilyTreeIndex index;

  setUp(() => index = FamilyTreeIndex(people));

  List<int> ids(List<TreeRow> rows) => rows.map((r) => r.person.id!).toList();

  test('الجذور: من لا والد له', () {
    expect(index.roots.map((e) => e.id), [1, 5]);
  });

  test('الابن يظهر تحت أبيه فقط، ومن لا أب له تحت أمه', () {
    expect(index.childrenOf(1).map((e) => e.id), [2, 3]);
    expect(index.childrenOf(2).map((e) => e.id), [4]);
    expect(index.childrenOf(5).map((e) => e.id), [6]);
  });

  test('كل شخص يظهر مرة واحدة عند فتح الكل', () {
    final rows = index.flatten(expanded: index.expandableIds);
    expect(ids(rows), [1, 2, 4, 3, 5, 6]);
    expect(rows.map((r) => r.depth), [0, 1, 2, 1, 0, 1]);
    expect(ids(rows).toSet().length, people.length);
  });

  test('الإغلاق يُظهر الجذور فقط', () {
    final rows = index.flatten();
    expect(ids(rows), [1, 5]);
    expect(rows.every((r) => r.hasVisibleChildren && !r.expanded), isTrue);
    expect(rows.first.childCount, 2);
  });

  test('فتح فرع واحد', () {
    final rows = index.flatten(expanded: {1});
    expect(ids(rows), [1, 2, 3, 5]);
  });

  test('البحث يُظهر المطابق وأسلافه فقط ويفتح المسار', () {
    final visible = index.withAncestors({4});
    expect(visible, {4, 2, 1});
    final rows = index.flatten(visible: visible, matches: {4});
    expect(ids(rows), [1, 2, 4]);
    expect(rows.firstWhere((r) => r.person.id == 4).isMatch, isTrue);
    expect(rows.firstWhere((r) => r.person.id == 1).isMatch, isFalse);
    expect(rows.firstWhere((r) => r.person.id == 1).expanded, isTrue);
    expect(rows.firstWhere((r) => r.person.id == 2).expanded, isTrue);
    expect(rows.any((r) => r.person.id == 3), isFalse);
  });

  test('والد غير موجود في القائمة يجعل الشخص جذراً', () {
    final idx = FamilyTreeIndex([p(10, 'يتيم', f: 999)]);
    expect(idx.roots.map((e) => e.id), [10]);
  });

  test('withAncestors آمنة ضد بيانات حلقية', () {
    final idx = FamilyTreeIndex([p(1, 'أ', f: 2), p(2, 'ب', f: 1)]);
    expect(idx.withAncestors({1}), {1, 2});
  });
}
