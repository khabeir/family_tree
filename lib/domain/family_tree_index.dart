import '../data/models/person.dart';

/// صف ظاهر في الشجرة بعد التسطيح.
class TreeRow {
  const TreeRow({
    required this.person,
    required this.depth,
    required this.childCount,
    required this.hasVisibleChildren,
    required this.expanded,
    required this.isMatch,
  });

  final Person person;
  final int depth;

  /// عدد الأبناء الكلي في الشجرة (بغض النظر عن الفلترة).
  final int childCount;
  final bool hasVisibleChildren;
  final bool expanded;
  final bool isMatch;
}

/// فهرس الشجرة: كل شخص يظهر مرة واحدة تحت أبيه، فإن لم يُعرف الأب فتحت أمه.
/// الجذور: من لا والد مسجّلاً له (أو والده غير موجود).
class FamilyTreeIndex {
  FamilyTreeIndex(List<Person> people) {
    for (final p in people) {
      _byId[p.id!] = p;
    }
    for (final p in people) {
      final parent = treeParentId(p);
      if (parent != null && _byId.containsKey(parent)) {
        (_children[parent] ??= []).add(p);
      } else {
        roots.add(p);
      }
    }
    for (final list in _children.values) {
      list.sort((a, b) { final c = a.sortOrder.compareTo(b.sortOrder); return c != 0 ? c : a.id!.compareTo(b.id!); });
    }
  }

  static int? treeParentId(Person p) => p.fatherId ?? p.motherId;

  final Map<int, Person> _byId = {};
  final Map<int, List<Person>> _children = {};
  final List<Person> roots = [];

  List<Person> childrenOf(int id) => _children[id] ?? const [];

  /// كل من لديه أبناء (لأمر «فتح الكل»).
  Set<int> get expandableIds => _children.keys.toSet();

  /// يضيف إلى [ids] كل أسلافهم في الشجرة.
  Set<int> withAncestors(Set<int> ids) {
    final result = <int>{};
    for (final id in ids) {
      int? current = id;
      while (current != null && _byId.containsKey(current) && result.add(current)) {
        current = treeParentId(_byId[current]!);
      }
    }
    return result;
  }

  /// يسطّح الشجرة إلى صفوف ظاهرة.
  /// - بدون [visible]: يُفتح ما في [expanded] فقط.
  /// - مع [visible] (وضع البحث): تظهر هذه العقد فقط وتُفتح كلها.
  List<TreeRow> flatten({
    Set<int> expanded = const {},
    Set<int>? visible,
    Set<int> matches = const {},
  }) {
    final rows = <TreeRow>[];

    void walk(Person p, int depth) {
      final id = p.id!;
      final all = childrenOf(id);
      final kids = visible == null
          ? all
          : all.where((c) => visible.contains(c.id)).toList();
      final open = kids.isNotEmpty && (visible != null || expanded.contains(id));
      rows.add(TreeRow(
        person: p,
        depth: depth,
        childCount: all.length,
        hasVisibleChildren: kids.isNotEmpty,
        expanded: open,
        isMatch: matches.contains(id),
      ));
      if (open) {
        for (final c in kids) {
          walk(c, depth + 1);
        }
      }
    }

    for (final r in roots) {
      if (visible == null || visible.contains(r.id)) {
        walk(r, 0);
      }
    }
    return rows;
  }
}
