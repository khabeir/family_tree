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
