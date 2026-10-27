import 'dart:math' as math;

import '../data/models/marriage.dart';
import '../data/models/person.dart';

enum MindKind { person, marriage }

/// عقدة في الخريطة الذهنية: شخص، أو علاقة زواج (يتفرع منها الأبناء).
class MindNode {
  const MindNode({
    required this.key,
    required this.kind,
    required this.person,
    this.marriage,
    this.spouse,
    this.children = const [],
  });

  /// مفتاح ثابت: p<id> للشخص، m<id> للزواج.
  final String key;
  final MindKind kind;

  /// للشخص: هو نفسه. لعقدة الزواج: صاحب الفرع (الذي يتفرع منه الزواج).
  final Person person;
  final Marriage? marriage;
  final Person? spouse;
  final List<MindNode> children;
}

/// يبني خريطة ذهنية لأحفاد شخص:
/// شخص ← عقد زواجه ← أبناء ذلك الزواج؛ ومن لا يُعرف له زواج مطابق يتفرع مباشرة من والده/والدته.
/// يظهر كل شخص وكل زواج مرة واحدة فقط.
class MindMapBuilder {
  MindMapBuilder(List<Person> people, List<Marriage> marriages) {
    for (final p in people) {
      _byId[p.id!] = p;
    }
    for (final p in people) {
      final f = p.fatherId;
      final m = p.motherId;
      if (f != null) (_kids[f] ??= []).add(p);
      if (m != null && m != f) (_kids[m] ??= []).add(p);
    }
    for (final m in marriages) {
      (_marriagesOf[m.person1Id] ??= []).add(m);
      (_marriagesOf[m.person2Id] ??= []).add(m);
    }
    for (final l in _kids.values) {
      l.sort((a, b) => a.id!.compareTo(b.id!));
    }
    for (final l in _marriagesOf.values) {
      l.sort((a, b) => a.id!.compareTo(b.id!));
    }
  }

  final Map<int, Person> _byId = {};
  final Map<int, List<Person>> _kids = {};
  final Map<int, List<Marriage>> _marriagesOf = {};

  int? _otherParent(Person kid, int parentId) =>
      kid.fatherId == parentId ? kid.motherId : kid.fatherId;

  MindNode? build(int rootId) {
    final root = _byId[rootId];
    if (root == null) return null;
    final visitedPersons = <int>{};
    final visitedMarriages = <int>{};

    MindNode personNode(Person p) {
      visitedPersons.add(p.id!);
      final children = <MindNode>[];
      final kids = _kids[p.id] ?? const <Person>[];
      final placed = <int>{};

      for (final m in _marriagesOf[p.id] ?? const <Marriage>[]) {
        if (!visitedMarriages.add(m.id!)) continue;
        final spouse = _byId[m.person1Id == p.id ? m.person2Id : m.person1Id];
        if (spouse == null) continue;
        final childNodes = <MindNode>[];
        for (final k in kids) {
          if (_otherParent(k, p.id!) != spouse.id) continue;
          placed.add(k.id!);
          if (!visitedPersons.contains(k.id)) {
            childNodes.add(personNode(k));
          }
        }
        children.add(MindNode(
          key: 'm${m.id}',
          kind: MindKind.marriage,
          person: p,
          marriage: m,
          spouse: spouse,
          children: childNodes,
        ));
      }

      for (final k in kids) {
        if (placed.contains(k.id) || visitedPersons.contains(k.id)) continue;
        children.add(personNode(k));
      }

      return MindNode(
        key: 'p${p.id}',
        kind: MindKind.person,
        person: p,
        children: children,
      );
    }

    return personNode(root);
  }
}

/// مفاتيح العقد التي لها أبناء وعمقها أقل من [depth] (لفتح مستوى ابتدائي).
Set<String> keysUpToDepth(MindNode root, int depth) {
  final keys = <String>{};
  void walk(MindNode n, int d) {
    if (n.children.isEmpty || d >= depth) return;
    keys.add(n.key);
    for (final c in n.children) {
      walk(c, d + 1);
    }
  }

  walk(root, 0);
  return keys;
}

Set<String> allExpandableKeys(MindNode root) => keysUpToDepth(root, 1 << 30);

class MindBox {
  MindBox(this.node, this.depth);

  final MindNode node;
  final int depth;
  double y = 0;
  bool expanded = false;
}

class MindEdge {
  const MindEdge(this.from, this.to);

  final int from;
  final int to;
}

class MindLayout {
  const MindLayout({
    required this.boxes,
    required this.edges,
    required this.maxDepth,
    required this.height,
  });

  final List<MindBox> boxes;
  final List<MindEdge> edges;
  final int maxDepth;
  final double height;
}

/// تخطيط شجري: الأوراق تُرصّ رأسياً، والأب في منتصف أبنائه، والعمق يحدّد العمود.
MindLayout layoutMindMap(
  MindNode root,
  Set<String> expanded, {
  double nodeH = 64,
  double gapY = 12,
}) {
  final boxes = <MindBox>[];
  final edges = <MindEdge>[];
  var nextY = 0.0;
  var maxDepth = 0;

  double place(MindNode n, int depth, int? parent) {
    final index = boxes.length;
    final box = MindBox(n, depth);
    boxes.add(box);
    if (parent != null) edges.add(MindEdge(parent, index));
    maxDepth = math.max(maxDepth, depth);

    final open = n.children.isNotEmpty && expanded.contains(n.key);
    box.expanded = open;
    if (!open) {
      box.y = nextY;
      nextY += nodeH + gapY;
    } else {
      var first = 0.0;
      var last = 0.0;
      for (var i = 0; i < n.children.length; i++) {
        final y = place(n.children[i], depth + 1, index);
        if (i == 0) first = y;
        last = y;
      }
      box.y = (first + last) / 2;
    }
    return box.y;
  }

  place(root, 0, null);
  return MindLayout(
    boxes: boxes,
    edges: edges,
    maxDepth: maxDepth,
    height: math.max(nextY - gapY, nodeH),
  );
}
