#!/usr/bin/env bash
# شجرة عائلتي - تطوير الخريطة الذهنية (v2)
# شغّله من جذر المستودع: bash patch_mindmap_v2.sh
set -euo pipefail

test -f lib/domain/mind_map.dart
test -f lib/ui/mind_map_screen.dart

# ───────────────────────── 1) منطق الخريطة: ارتفاعات متغيرة + ألوان الفروع + مسار البحث ─────────────────────────
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
DART_EOF

# ───────────────────────── 2) شاشة الخريطة v2 ─────────────────────────
cat > lib/ui/mind_map_screen.dart <<'DART_EOF'
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../data/models/marriage.dart';
import '../data/models/person.dart';
import '../domain/family_tree_index.dart';
import '../domain/mind_map.dart';
import 'person_detail_screen.dart';
import 'person_picker_screen.dart';
import 'ui_helpers.dart';

const List<Color> _palette = [
  Color(0xFFD81B60),
  Color(0xFF00897B),
  Color(0xFF3949AB),
  Color(0xFFF57C00),
  Color(0xFF43A047),
  Color(0xFF8E24AA),
  Color(0xFF6D4C41),
  Color(0xFF1E88E5),
];

Color _branchColor(int branch) =>
    branch < 0 ? const Color(0xFF283593) : _palette[branch % _palette.length];

enum _ViewRequest { none, reset, fit }

class _NodeStyle {
  const _NodeStyle({
    required this.label,
    required this.fontSize,
    required this.weight,
    required this.maxLines,
    required this.maxTextW,
    required this.padH,
    required this.padV,
    required this.extraW,
  });

  final String label;
  final double fontSize;
  final FontWeight weight;
  final int maxLines;
  final double maxTextW;
  final double padH;
  final double padV;
  final double extraW;
}

class MindMapScreen extends StatefulWidget {
  const MindMapScreen({super.key, required this.state, this.initialRootId});

  final AppState state;
  final int? initialRootId;

  @override
  State<MindMapScreen> createState() => _MindMapScreenState();
}

class _MindMapScreenState extends State<MindMapScreen> {
  static const double gapX = 34;
  static const double gapY = 10;
  static const double pad = 28;
  static const double dotSize = 22;
  static const double dotExt = 16; // الجزء الظاهر خارج العقدة
  static const double dotOverlap = dotSize - dotExt;

  final _tc = TransformationController();
  final _canvasKey = GlobalKey();
  final Map<String, Size> _measureCache = {};

  int? _rootId;
  int? _initializedFor;
  Set<String> _expanded = {};
  bool _rootOnRight = false;
  bool _fullNames = false;
  String? _highlightKey;
  String? _focusKey;
  _ViewRequest _view = _ViewRequest.reset;

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

  // ───── قياس النص: عرض العقدة بقدر الاسم بلا هوامش كبيرة ─────

  Size _measure(_NodeStyle s) {
    final key =
        '${s.fontSize}|${s.weight.index}|${s.maxTextW}|${s.maxLines}|${s.label}';
    return _measureCache.putIfAbsent(key, () {
      final tp = TextPainter(
        text: TextSpan(
          text: s.label,
          style: TextStyle(
            inherit: false,
            fontSize: s.fontSize,
            fontWeight: s.weight,
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: s.maxLines,
        ellipsis: '…',
        textWidthBasis: TextWidthBasis.longestLine,
      )..layout(maxWidth: s.maxTextW);
      final size = Size(tp.width, tp.height);
      tp.dispose();
      return size;
    });
  }

  Size _nodeSize(_NodeStyle s) {
    final t = _measure(s);
    return Size(
      math.max(44, t.width + 4 + 2 * s.padH + s.extraW),
      math.max(30, t.height + 2 * s.padV),
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

  _NodeStyle _styleOf(MindNode n, int depth) {
    if (n.kind == MindKind.marriage) {
      return _NodeStyle(
        label: _marriageLabel(n),
        fontSize: 13,
        weight: FontWeight.w500,
        maxLines: 3,
        maxTextW: 190,
        padH: 9,
        padV: 5,
        extraW: 18,
      );
    }
    final isRoot = depth == 0;
    return _NodeStyle(
      label: isRoot || _fullNames
          ? widget.state.displayName(n.person)
          : n.person.name,
      fontSize: isRoot ? 16 : 14,
      weight: isRoot ? FontWeight.w700 : FontWeight.w600,
      maxLines: isRoot ? 3 : 2,
      maxTextW: isRoot ? 240 : 190,
      padH: isRoot ? 16 : 10,
      padV: isRoot ? 9 : 6,
      extraW: 0,
    );
  }

  // ───── إجراءات ─────

  void _openPerson(Person p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonDetailScreen(state: widget.state, personId: p.id!),
      ),
    );
  }

  void _toggle(String key) {
    setState(() {
      if (!_expanded.remove(key)) _expanded.add(key);
    });
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
      setState(() {
        _rootId = picked.id;
        _highlightKey = null;
      });
    }
  }

  Future<void> _findInMap(MindNode root) async {
    final picked = await Navigator.of(context).push<Person>(
      MaterialPageRoute(
        builder: (_) => PersonPickerScreen(
          state: widget.state,
          title: 'بحث في الخريطة',
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final path = keyPathToPerson(root, picked.id!);
    if (path == null) {
      final ok = await confirmDialog(
        context,
        title: 'خارج الخريطة الحالية',
        message:
            '«${widget.state.displayName(picked)}» ليس من أحفاد الجذر الحالي. هل تجعله جذر الخريطة؟',
        confirmLabel: 'جعله جذراً',
      );
      if (ok && mounted) {
        setState(() {
          _rootId = picked.id;
          _highlightKey = null;
        });
      }
      return;
    }
    setState(() {
      _expanded.addAll(path.sublist(0, path.length - 1));
      _highlightKey = path.last;
      _focusKey = path.last;
    });
  }

  void _nodeMenu(Person p) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                widget.state.displayName(p),
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('فتح التفاصيل'),
              onTap: () {
                Navigator.of(ctx).pop();
                _openPerson(p);
              },
            ),
            ListTile(
              leading: const Icon(Icons.account_tree),
              title: const Text('جعله جذر الخريطة'),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() {
                  _rootId = p.id;
                  _highlightKey = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportImage() async {
    final ctx = _canvasKey.currentContext;
    if (ctx == null) return;
    try {
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
      final longest = math.max(boundary.size.width, boundary.size.height);
      final ratio = math.min(2.0, 4096 / longest);
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('فشل إنشاء الصورة');
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/family_tree_map.png');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'خريطة العائلة',
      );
    } catch (e) {
      if (mounted) showMessage(context, 'تعذّر حفظ الصورة: $e');
    }
  }

  Matrix4 _matrix(double s, double tx, double ty) =>
      Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1);

  // ───── العقدة ─────

  Widget _nodeWidget({
    required MindBox box,
    required Size size,
    required Rect eff,
    required _NodeStyle style,
  }) {
    final n = box.node;
    final isRoot = box.depth == 0;
    final isMarriage = n.kind == MindKind.marriage;
    final hasKids = n.children.isNotEmpty;
    final color = _branchColor(box.branch);
    final highlighted = _highlightKey == n.key;

    Color fill;
    Color textColor = Colors.black87;
    if (isRoot) {
      fill = const Color(0xFF283593);
      textColor = Colors.white;
    } else if (isMarriage) {
      fill = Colors.amber.shade50;
    } else {
      fill = switch (n.person.gender) {
        Gender.male => Colors.blue.shade50,
        Gender.female => Colors.pink.shade50,
        Gender.unknown => Colors.grey.shade100,
      };
    }

    final radius = BorderRadius.circular(isRoot ? 22 : (isMarriage ? 14 : 10));
    final textStyle = TextStyle(
      inherit: false,
      fontSize: style.fontSize,
      fontWeight: style.weight,
      height: 1.2,
      color: textColor,
    );
    final text = Text(
      style.label,
      textAlign: TextAlign.center,
      maxLines: style.maxLines,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );

    final body = Material(
      color: fill,
      elevation: highlighted ? 8 : 1.5,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: highlighted ? Colors.amber.shade800 : color,
          width: highlighted ? 3.5 : 2,
        ),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(borderRadius: radius),
        onTap: () => _openPerson(isMarriage ? n.spouse! : n.person),
        onLongPress: isMarriage ? null : () => _nodeMenu(n.person),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: style.padH,
            vertical: style.padV,
          ),
          child: Center(
            child: isMarriage
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.favorite, size: 14, color: Colors.red.shade300),
                      const SizedBox(width: 4),
                      Flexible(child: text),
                    ],
                  )
                : text,
          ),
        ),
      ),
    );

    final dot = hasKids
        ? Positioned(
            top: (size.height - dotSize) / 2,
            left: _rootOnRight ? 0 : size.width - dotOverlap,
            width: dotSize,
            height: dotSize,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggle(n.key),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: box.expanded
                    ? const Icon(Icons.remove, size: 14, color: Colors.white)
                    : Text(
                        n.children.length > 99 ? '99+' : '${n.children.length}',
                        style: const TextStyle(
                          inherit: false,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          )
        : null;

    return Positioned(
      left: eff.left,
      top: eff.top,
      width: eff.width,
      height: eff.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _rootOnRight && hasKids ? dotExt : 0,
            top: 0,
            width: size.width,
            height: size.height,
            child: body,
          ),
          if (dot != null) dot,
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
          _view = _ViewRequest.reset;
        }

        // ───── التخطيط والقياس ─────
        final layout = layoutMindMap(
          root,
          _expanded,
          gapY: gapY,
          heightOf: (n, d) => _nodeSize(_styleOf(n, d)).height,
        );
        final styles = [
          for (final b in layout.boxes) _styleOf(b.node, b.depth),
        ];
        final sizes = [for (final s in styles) _nodeSize(s)];

        final colW = List<double>.filled(layout.maxDepth + 1, 0);
        for (var i = 0; i < layout.boxes.length; i++) {
          final b = layout.boxes[i];
          final ext = b.node.children.isNotEmpty ? dotExt : 0.0;
          colW[b.depth] = math.max(colW[b.depth], sizes[i].width + ext);
        }
        final off = <double>[];
        var acc = 0.0;
        for (final w in colW) {
          off.add(acc);
          acc += w + gapX;
        }
        final canvasW = (acc - gapX) + pad * 2;
        final canvasH = layout.height + pad * 2;

        final effRects = <Rect>[];
        for (var i = 0; i < layout.boxes.length; i++) {
          final b = layout.boxes[i];
          final ext = b.node.children.isNotEmpty ? dotExt : 0.0;
          final w = sizes[i].width + ext;
          final left = _rootOnRight
              ? canvasW - pad - off[b.depth] - w
              : pad + off[b.depth];
          effRects.add(Rect.fromLTWH(left, pad + b.y, w, sizes[i].height));
        }

        final edgeColors = [
          for (final e in layout.edges) _branchColor(layout.boxes[e.to].branch),
        ];
        final edgeWidths = [
          for (final e in layout.edges)
            math.max(2.5, 4.5 - 0.5 * layout.boxes[e.to].depth),
        ];

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'خريطة: ${state.displayName(state.byId(rootId)!)}',
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                tooltip: 'بحث في الخريطة',
                icon: const Icon(Icons.search),
                onPressed: () => _findInMap(root),
              ),
              IconButton(
                tooltip: 'ملاءمة الشاشة',
                icon: const Icon(Icons.fit_screen),
                onPressed: () => setState(() => _view = _ViewRequest.fit),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  switch (v) {
                    case 'root':
                      _pickRoot();
                    case 'image':
                      _exportImage();
                    default:
                      setState(() {
                        switch (v) {
                          case 'open':
                            _expanded = allExpandableKeys(root);
                          case 'close':
                            _expanded = keysUpToDepth(root, 1);
                          case 'dir':
                            _rootOnRight = !_rootOnRight;
                            _view = _ViewRequest.reset;
                          case 'names':
                            _fullNames = !_fullNames;
                          case 'reset':
                            _view = _ViewRequest.reset;
                        }
                      });
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'root', child: Text('اختيار الجذر')),
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
                  const PopupMenuItem(value: 'reset', child: Text('إعادة التمركز')),
                  const PopupMenuItem(value: 'image', child: Text('حفظ كصورة PNG')),
                ],
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final vw = constraints.maxWidth;
              final vh = constraints.maxHeight;
              final focus = _focusKey;
              final req = _view;
              if (focus != null || req != _ViewRequest.none) {
                _focusKey = null;
                _view = _ViewRequest.none;
                Matrix4? m;
                if (focus != null) {
                  final i = layout.boxes.indexWhere((b) => b.node.key == focus);
                  if (i >= 0) {
                    final c = effRects[i].center;
                    m = _matrix(1, vw / 2 - c.dx, vh / 2 - c.dy);
                  }
                }
                if (m == null) {
                  if (req == _ViewRequest.fit) {
                    final s = math
                        .min(vw / canvasW, vh / canvasH)
                        .clamp(0.2, 1.0)
                        .toDouble();
                    m = _matrix(s, (vw - canvasW * s) / 2, (vh - canvasH * s) / 2);
                  } else {
                    final tx = _rootOnRight ? math.min(0.0, vw - canvasW) : 0.0;
                    final ty = canvasH < vh ? (vh - canvasH) / 2 : 0.0;
                    m = _matrix(1, tx, ty);
                  }
                }
                final target = m;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _tc.value = target;
                });
              }

              return InteractiveViewer(
                transformationController: _tc,
                constrained: false,
                minScale: 0.1,
                maxScale: 3,
                boundaryMargin: const EdgeInsets.all(600),
                child: RepaintBoundary(
                  key: _canvasKey,
                  child: ColoredBox(
                    color: Colors.white,
                    child: SizedBox(
                      width: canvasW,
                      height: canvasH,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _EdgesPainter(
                                rects: effRects,
                                edges: layout.edges,
                                colors: edgeColors,
                                widths: edgeWidths,
                                rootOnRight: _rootOnRight,
                              ),
                            ),
                          ),
                          for (var i = 0; i < layout.boxes.length; i++)
                            _nodeWidget(
                              box: layout.boxes[i],
                              size: sizes[i],
                              eff: effRects[i],
                              style: styles[i],
                            ),
                        ],
                      ),
                    ),
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
    required this.colors,
    required this.widths,
    required this.rootOnRight,
  });

  final List<Rect> rects;
  final List<MindEdge> edges;
  final List<Color> colors;
  final List<double> widths;
  final bool rootOnRight;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < edges.length; i++) {
      final e = edges[i];
      final a = rects[e.from];
      final b = rects[e.to];
      final sx = rootOnRight ? a.left : a.right;
      final ex = rootOnRight ? b.right : b.left;
      final sy = a.center.dy;
      final ey = b.center.dy;
      final mx = (sx + ex) / 2;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = widths[i];
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

# ───────────────────────── 3) الاختبارات ─────────────────────────
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

  test('مسار مفاتيح الوصول إلى شخص', () {
    final root = MindMapBuilder(people, marriages).build(1)!;
    expect(keyPathToPerson(root, 8), ['p1', 'm1', 'p4', 'm3', 'p8']);
    expect(keyPathToPerson(root, 1), ['p1']);
    // الزوجة تظهر داخل عقدة الزواج فقط وليست عقدة شخص
    expect(keyPathToPerson(root, 2), isNull);
    expect(keyPathToPerson(root, 999), isNull);
  });

  group('التخطيط', () {
    test('مغلق ثم مفتوح بارتفاع ثابت', () {
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

    test('ارتفاعات متغيرة بحسب العقدة', () {
      final root = MindMapBuilder(people, marriages).build(1)!;
      final l = layoutMindMap(
        root,
        {'p1'},
        gapY: 12,
        heightOf: (n, d) => n.key == 'p1' ? 80 : 40,
      );
      expect(l.boxes.map((b) => b.y), [32, 0, 52, 104]);
      expect(l.boxes.map((b) => b.height), [80, 40, 40, 40]);
      expect(l.height, 144);
    });

    test('الأب الأطول من ابنه الوحيد لا يخرج عن الحدود العليا', () {
      final root = MindMapBuilder(
        [p(1, 'أ', Gender.male), p(2, 'ب', Gender.female)],
        [mar(1, 1, 2)],
      ).build(1)!;
      final l = layoutMindMap(
        root,
        {'p1'},
        heightOf: (n, d) => d == 0 ? 100 : 40,
      );
      expect(l.boxes.first.y, 0);
      expect(l.height, 100);
    });

    test('لا تتداخل عقد العمود الواحد', () {
      final root = MindMapBuilder(people, marriages).build(1)!;
      final l = layoutMindMap(
        root,
        allExpandableKeys(root),
        gapY: 8,
        heightOf: (n, d) => (n.key.hashCode % 3 + 1) * 20.0,
      );
      for (var d = 0; d <= l.maxDepth; d++) {
        final col = l.boxes.where((b) => b.depth == d).toList()
          ..sort((a, b) => a.y.compareTo(b.y));
        for (var i = 1; i < col.length; i++) {
          expect(col[i].y, greaterThanOrEqualTo(col[i - 1].y + col[i - 1].height));
        }
      }
    });

    test('أرقام الفروع للتلوين', () {
      final root = MindMapBuilder(people, marriages).build(1)!;
      final l = layoutMindMap(root, allExpandableKeys(root));
      MindBox box(String k) => l.boxes.firstWhere((b) => b.node.key == k);
      expect(box('p1').branch, -1);
      expect(box('m1').branch, 0);
      expect(box('p4').branch, 0);
      expect(box('p8').branch, 0);
      expect(box('m2').branch, 1);
      expect(box('p6').branch, 1);
      expect(box('p9').branch, 2);
    });
  });
}
DART_EOF

echo "تم تطبيق تطوير الخريطة الذهنية."
