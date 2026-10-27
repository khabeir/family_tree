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

/// مفاتيح العقد من الجذر حتى عقدة الشخص [personId] (شاملة)، أو null إن لم يكن عقدة في الخريطة.
List<String>? keyPathToPerson(MindNode root, int personId) {
  List<String>? walk(MindNode n, List<String> acc) {
    final next = [...acc, n.key];
    if (n.kind == MindKind.person && n.person.id == personId) return next;
    for (final c in n.children) {
      final r = walk(c, next);
      if (r != null) return r;
    }
    return null;
  }

  return walk(root, const []);
}

class MindBox {
  MindBox(this.node, this.depth, this.branch);

  final MindNode node;
  final int depth;

  /// رقم الفرع الرئيسي (ترتيب الابن المباشر للجذر)؛ -1 للجذر. يُستخدم للتلوين.
  final int branch;

  double y = 0;
  double height = 0;
  bool expanded = false;

  double get centerY => y + height / 2;
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

/// تخطيط شجري: الأوراق تُرصّ رأسياً حسب ارتفاع كل عقدة، والأب في منتصف أبنائه،
/// والعمق يحدّد العمود. [heightOf] يحدّد ارتفاع كل عقدة (وإلا [nodeH] للجميع).
MindLayout layoutMindMap(
  MindNode root,
  Set<String> expanded, {
  double nodeH = 64,
  double gapY = 12,
  double Function(MindNode node, int depth)? heightOf,
}) {
  final boxes = <MindBox>[];
  final edges = <MindEdge>[];
  final colBottom = <int, double>{};
  var nextY = 0.0;
  var maxDepth = 0;

  // يعيد مركز العقدة الرأسي
  double place(MindNode n, int depth, int? parent, int branch) {
    final index = boxes.length;
    final h = heightOf?.call(n, depth) ?? nodeH;
    final box = MindBox(n, depth, branch)..height = h;
    boxes.add(box);
    if (parent != null) edges.add(MindEdge(parent, index));
    maxDepth = math.max(maxDepth, depth);

    final open = n.children.isNotEmpty && expanded.contains(n.key);
    box.expanded = open;
    final floor = colBottom[depth] ?? 0.0;

    if (!open) {
      final top = math.max(nextY, floor);
      box.y = top;
      nextY = top + h + gapY;
    } else {
      var first = 0.0;
      var last = 0.0;
      for (var i = 0; i < n.children.length; i++) {
        final c = place(n.children[i], depth + 1, index, depth == 0 ? i : branch);
        if (i == 0) first = c;
        last = c;
      }
      box.y = math.max((first + last) / 2 - h / 2, floor);
    }
    colBottom[depth] = box.y + h + gapY;
    return box.centerY;
  }

  place(root, 0, null, -1);
  var bottom = 0.0;
  for (final b in boxes) {
    bottom = math.max(bottom, b.y + b.height);
  }
  return MindLayout(
    boxes: boxes,
    edges: edges,
    maxDepth: maxDepth,
    height: math.max(bottom, 1),
  );
}
