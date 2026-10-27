#!/usr/bin/env bash
# شجرة عائلتي - المرحلة 3ب: الخريطة الذهنية
# شغّله من جذر المستودع بعد نجاح المرحلة 3: bash setup_phase3b_mindmap.sh
set -euo pipefail

mkdir -p lib/domain lib/ui test

# ───────────────────────── 1) AppState: تخزين كل علاقات الزواج في الذاكرة ─────────────────────────
if ! grep -q "allMarriages" lib/app_state.dart; then
  sed -i '/Map<int, String> _display = const {};/a\  List<Marriage> _marriages = const [];\n\n  List<Marriage> get allMarriages => _marriages;' lib/app_state.dart
  sed -i '/final rows = await persons.getAll();/a\    _marriages = await marriages.getAll();' lib/app_state.dart
  sed -i '/final id = await service.addMarriage(m);/a\    _marriages = await marriages.getAll();' lib/app_state.dart
  sed -i '/final ok = await service.updateMarriage(m);/a\    _marriages = await marriages.getAll();' lib/app_state.dart
  sed -i '/final ok = await service.deleteMarriage(id);/a\    _marriages = await marriages.getAll();' lib/app_state.dart
fi
grep -q "allMarriages" lib/app_state.dart
test "$(grep -c '_marriages = await marriages.getAll();' lib/app_state.dart)" = "4"

# ───────────────────────── 2) منطق الخريطة (Dart صرف) ─────────────────────────
cat > lib/domain/mind_map.dart <<'DART_EOF'
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
DART_EOF

# ───────────────────────── 3) شاشة الخريطة ─────────────────────────
cat > lib/ui/mind_map_screen.dart <<'DART_EOF'
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/marriage.dart';
import '../data/models/person.dart';
import '../domain/family_tree_index.dart';
import '../domain/mind_map.dart';
import 'person_detail_screen.dart';
import 'person_picker_screen.dart';

class MindMapScreen extends StatefulWidget {
  const MindMapScreen({super.key, required this.state, this.initialRootId});

  final AppState state;
  final int? initialRootId;

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  static const double nodeW = 170;
  static const double nodeH = 64;
  static const double gapX = 44;
  static const double gapY = 12;
  static const double pad = 24;

  final _tc = TransformationController();
  int? _rootId;
  int? _initializedFor;
  Set<String> _expanded = {};
  bool _rootOnRight = false;
  bool _fullNames = false;
  bool _pendingRecenter = true;

  @override
  void initState() {
    super.initState();
    _rootId = widget.initialRootId;
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _pickRoot() async {
    final picked = await Navigator.of(context).push<Person>(
      MaterialPageRoute(
        builder: (_) => PersonPickerScreen(
          state: widget.state,
          title: 'اختيار جذر الخريطة',
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _rootId = picked.id);
    }
  }

  void _toggle(String key) {
    setState(() {
      if (!_expanded.remove(key)) _expanded.add(key);
    });
  }

  void _openPerson(Person p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonDetailScreen(state: widget.state, personId: p.id!),
      ),
    );
  }

  String _marriageLabel(MindNode n) {
    final owner = n.person;
    final name = widget.state.displayName(n.spouse!);
    final verb = switch (owner.gender) {
      Gender.female => 'تزوجها',
      Gender.male => 'تزوج',
      Gender.unknown => 'زواج من',
    };
    final suffix = switch (n.marriage!.status) {
      MarriageStatus.married => '',
      MarriageStatus.divorced => ' (طلاق)',
      MarriageStatus.widowed => ' (انتهى بوفاة)',
    };
    return '$verb $name$suffix';
  }

  Widget _nodeWidget(MindBox box, Rect rect) {
    final state = widget.state;
    final n = box.node;
    final isRoot = box.depth == 0;
    final isMarriage = n.kind == MindKind.marriage;
    final label = isMarriage
        ? _marriageLabel(n)
        : (isRoot || _fullNames ? state.displayName(n.person) : n.person.name);
    final hasKids = n.children.isNotEmpty;
    final pink = Colors.pink.shade300;

    final textPad = EdgeInsets.only(
      left: _rootOnRight && hasKids ? 24 : 8,
      right: !_rootOnRight && hasKids ? 24 : 8,
      top: 4,
      bottom: 4,
    );

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: isRoot
                  ? Colors.grey.shade300
                  : (isMarriage ? Colors.pink.shade50 : Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isRoot ? 32 : 8),
                side: BorderSide(color: pink, width: 1.5),
              ),
              child: InkWell(
                customBorder: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isRoot ? 32 : 8),
                ),
                onTap: () => _openPerson(isMarriage ? n.spouse! : n.person),
                child: Padding(
                  padding: textPad,
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: isRoot ? Colors.indigo.shade800 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (hasKids)
            Positioned(
              top: (nodeH - 22) / 2,
              left: _rootOnRight ? 3 : null,
              right: _rootOnRight ? null : 3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _toggle(n.key),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: pink, width: 1.5),
                  ),
                  child: Icon(
                    box.expanded ? Icons.remove : Icons.add,
                    size: 14,
                    color: pink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        var rootId = _rootId;
        if (rootId == null || state.byId(rootId) == null) {
          final roots = FamilyTreeIndex(state.all).roots;
          rootId = roots.isEmpty ? null : roots.first.id;
        }
        if (rootId == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('الخريطة الذهنية')),
            body: const Center(child: Text('لا يوجد أفراد بعد.')),
          );
        }

        final root = MindMapBuilder(state.all, state.allMarriages).build(rootId)!;
        if (_initializedFor != rootId) {
          _initializedFor = rootId;
          _expanded = keysUpToDepth(root, 3);
          _pendingRecenter = true;
        }

        final layout = layoutMindMap(root, _expanded, nodeH: nodeH, gapY: gapY);
        const step = nodeW + gapX;
        final canvasW = pad * 2 + (layout.maxDepth + 1) * step - gapX;
        final canvasH = pad * 2 + layout.height;

        final rects = <Rect>[
          for (final b in layout.boxes)
            Rect.fromLTWH(
              _rootOnRight
                  ? canvasW - pad - nodeW - b.depth * step
                  : pad + b.depth * step,
              pad + b.y,
              nodeW,
              nodeH,
            ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'خريطة: ${state.displayName(state.byId(rootId)!)}',
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: 'اختيار الجذر',
                icon: const Icon(Icons.person_search),
                onPressed: _pickRoot,
              ),
              IconButton(
                tooltip: 'إعادة التمركز',
                icon: const Icon(Icons.center_focus_strong),
                onPressed: () => setState(() => _pendingRecenter = true),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  setState(() {
                    switch (v) {
                      case 'open':
                        _expanded = allExpandableKeys(root);
                      case 'close':
                        _expanded = keysUpToDepth(root, 1);
                      case 'dir':
                        _rootOnRight = !_rootOnRight;
                        _pendingRecenter = true;
                      case 'names':
                        _fullNames = !_fullNames;
                    }
                  });
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'open', child: Text('فتح كل الفروع')),
                  const PopupMenuItem(value: 'close', child: Text('إغلاق الفروع')),
                  PopupMenuItem(
                    value: 'dir',
                    child: Text(_rootOnRight
                        ? 'الجذر على اليسار'
                        : 'الجذر على اليمين'),
                  ),
                  CheckedPopupMenuItem(
                    value: 'names',
                    checked: _fullNames,
                    child: const Text('الأسماء الكاملة'),
                  ),
                ],
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (_pendingRecenter) {
                _pendingRecenter = false;
                final dx = _rootOnRight
                    ? math.min(0.0, constraints.maxWidth - canvasW)
                    : 0.0;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    _tc.value = Matrix4.translationValues(dx, 0, 0);
                  }
                });
              }
              return InteractiveViewer(
                transformationController: _tc,
                constrained: false,
                minScale: 0.2,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(400),
                child: SizedBox(
                  width: canvasW,
                  height: canvasH,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _EdgesPainter(
                            rects: rects,
                            edges: layout.edges,
                            rootOnRight: _rootOnRight,
                            color: Colors.pink.shade300,
                          ),
                        ),
                      ),
                      for (var i = 0; i < layout.boxes.length; i++)
                        _nodeWidget(layout.boxes[i], rects[i]),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _EdgesPainter extends CustomPainter {
  _EdgesPainter({
    required this.rects,
    required this.edges,
    required this.rootOnRight,
    required this.color,
  });

  final List<Rect> rects;
  final List<MindEdge> edges;
  final bool rootOnRight;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final e in edges) {
      final a = rects[e.from];
      final b = rects[e.to];
      final sx = rootOnRight ? a.left : a.right;
      final ex = rootOnRight ? b.right : b.left;
      final sy = a.center.dy;
      final ey = b.center.dy;
      final mx = (sx + ex) / 2;
      final path = Path()
        ..moveTo(sx, sy)
        ..cubicTo(mx, sy, mx, ey, ex, ey);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _EdgesPainter old) => true;
}
DART_EOF

# ───────────────────────── 4) تبويب ثالث في الشاشة الرئيسية ─────────────────────────
cat > lib/ui/home_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import 'mind_map_screen.dart';
import 'person_list_screen.dart';
import 'tree_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          PersonListScreen(state: widget.state),
          TreeScreen(state: widget.state),
          MindMapScreen(state: widget.state),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: 'الأفراد'),
          NavigationDestination(icon: Icon(Icons.account_tree), label: 'الشجرة'),
          NavigationDestination(icon: Icon(Icons.hub), label: 'الخريطة'),
        ],
      ),
    );
  }
}
DART_EOF

# ───────────────────────── 5) زر الخريطة في صفحة تفاصيل الشخص ─────────────────────────
if ! grep -q "mind_map_screen.dart" lib/ui/person_detail_screen.dart; then
  test "$(grep -c 'actions: \[' lib/ui/person_detail_screen.dart)" = "1"
  sed -i "/import 'marriage_form_screen.dart';/a\import 'mind_map_screen.dart';" lib/ui/person_detail_screen.dart
  sed -i "/actions: \[\$/a\              IconButton(\n                tooltip: 'خريطة ذهنية',\n                icon: const Icon(Icons.hub),\n                onPressed: () => Navigator.of(context).push(\n                  MaterialPageRoute(\n                    builder: (_) =>\n                        MindMapScreen(state: state, initialRootId: personId),\n                  ),\n                ),\n              )," lib/ui/person_detail_screen.dart
fi
grep -q "Icons.hub" lib/ui/person_detail_screen.dart
grep -q "import 'mind_map_screen.dart';" lib/ui/person_detail_screen.dart

# ───────────────────────── 6) الاختبارات ─────────────────────────
cat > test/mind_map_test.dart <<'DART_EOF'
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
DART_EOF

echo "تم إنشاء ملفات الخريطة الذهنية."
