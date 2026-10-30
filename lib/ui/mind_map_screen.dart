import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../app_state.dart';
import '../data/models/marriage.dart';
import '../data/models/person.dart';
import '../domain/family_tree_index.dart';
import '../domain/mind_map.dart';
import 'person_detail_screen.dart';
import 'person_picker_screen.dart';
import 'branding.dart';
import 'image_export.dart';
import 'ui_helpers.dart';

const List<Color> _palette = [
  Color(0xFFD81B60),
  Color(0xFFC62828),
  Color(0xFF3949AB),
  Color(0xFFF57C00),
  Color(0xFF455A64),
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
  const MindMapScreen({
    super.key,
    required this.state,
    this.initialRootId,
    this.fullscreen = false,
    this.initialExpanded,
    this.initialRootOnRight = false,
    this.initialFullNames = false,
  });

  final AppState state;
  final int? initialRootId;

  /// وضع ملء الشاشة: بلا شريط علوي ولا أشرطة النظام، مع تدوير للعرض الأفقي.
  final bool fullscreen;
  final Set<String>? initialExpanded;
  final bool initialRootOnRight;
  final bool initialFullNames;

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
  int? _currentRootId;
  int? _initializedFor;
  Set<String> _expanded = {};
  bool _rootOnRight = false;
  bool _fullNames = false;
  bool _landscape = true;
  String? _highlightKey;
  String? _focusKey;
  Size? _lastViewport;
  bool _exporting = false;
  ImageQuality _quality = ImageQuality.fhd;
  _ViewRequest _view = _ViewRequest.reset;

  @override
  void initState() {
    super.initState();
    _rootId = widget.initialRootId;
    _rootOnRight = widget.initialRootOnRight;
    _fullNames = widget.initialFullNames;
    final initial = widget.initialExpanded;
    if (initial != null && widget.initialRootId != null) {
      _expanded = {...initial};
      _initializedFor = widget.initialRootId;
    }
    if (widget.fullscreen) {
      _applyOrientation();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  @override
  void dispose() {
    if (widget.fullscreen) {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _tc.dispose();
    super.dispose();
  }

  void _applyOrientation() {
    SystemChrome.setPreferredOrientations(
      _landscape
          ? [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : [DeviceOrientation.portraitUp],
    );
  }

  void _toggleOrientation() {
    setState(() => _landscape = !_landscape);
    _applyOrientation();
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MindMapScreen(
          state: widget.state,
          initialRootId: _currentRootId,
          fullscreen: true,
          initialExpanded: {..._expanded},
          initialRootOnRight: _rootOnRight,
          initialFullNames: _fullNames,
        ),
      ),
    );
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

  // ───── الصورة ─────

  String _stamp() {
    final n = DateTime.now();
    String t(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${t(n.month)}-${t(n.day)}_${t(n.hour)}${t(n.minute)}';
  }

  /// يلتقط الخريطة كاملة (لا المنطقة الظاهرة فقط) بخلفية بيضاء.
  Future<Uint8List> _capturePng() async {
    // يظهر شريط حقوق التصميم أسفل الخريطة أثناء الالتقاط فقط
    setState(() => _exporting = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final ctx = _canvasKey.currentContext;
      if (ctx == null) throw StateError('الخريطة غير جاهزة بعد');
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
      final ratio = _quality.ratioFor(boundary.size);
      final image = await boundary.toImage(pixelRatio: ratio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('فشل إنشاء الصورة');
      return data.buffer.asUint8List();
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// حفظ الصورة في الجهاز: يفتح نافذة النظام لاختيار المجلد والاسم.
  Future<void> _saveImage() async {
    try {
      final q = await askImageQuality(context, _quality);
      if (q == null) return;
      _quality = q;
      final bytes = await _capturePng();
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'حفظ صورة الخريطة',
        fileName: 'family_tree_map_${_stamp()}.png',
        bytes: bytes,
      );
      if (path != null && mounted) {
        showMessage(context, 'تم حفظ الصورة');
      }
    } catch (e) {
      if (mounted) showMessage(context, 'تعذّر حفظ الصورة: $e');
    }
  }

  /// مشاركة الصورة عبر قائمة المشاركة (واتساب، البريد، ...).
  Future<void> _shareImage() async {
    try {
      final q = await askImageQuality(context, _quality);
      if (q == null) return;
      _quality = q;
      final bytes = await _capturePng();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/family_tree_map_${_stamp()}.png');
      await file.writeAsBytes(bytes, flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        subject: 'خريطة العائلة',
      );
    } catch (e) {
      if (mounted) showMessage(context, 'تعذّرت المشاركة: $e');
    }
  }

  Matrix4 _matrix(double s, double tx, double ty) =>
      Matrix4(s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1);

  void _onMenu(String v, MindNode root) {
    switch (v) {
      case 'root':
        _pickRoot();
      case 'share':
        _shareImage();
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
  }

  Widget _menuButton(MindNode root) {
    return PopupMenuButton<String>(
      onSelected: (v) => _onMenu(v, root),
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'root', child: Text('اختيار الجذر')),
        const PopupMenuItem(value: 'open', child: Text('فتح كل الفروع')),
        const PopupMenuItem(value: 'close', child: Text('إغلاق الفروع')),
        PopupMenuItem(
          value: 'dir',
          child: Text(_rootOnRight ? 'الجذر على اليسار' : 'الجذر على اليمين'),
        ),
        CheckedPopupMenuItem(
          value: 'names',
          checked: _fullNames,
          child: const Text('الأسماء الكاملة'),
        ),
        const PopupMenuItem(value: 'reset', child: Text('إعادة التمركز')),
        const PopupMenuItem(value: 'share', child: Text('مشاركة كصورة')),
      ],
    );
  }

  /// شريط أدوات عائم صغير لوضع ملء الشاشة.
  Widget _fullscreenBar(MindNode root) {
    return Material(
      color: const Color(0xEBFFFFFF),
      elevation: 4,
      borderRadius: BorderRadius.circular(28),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'خروج من ملء الشاشة',
            icon: const Icon(Icons.fullscreen_exit),
            onPressed: () => Navigator.of(context).pop(),
          ),
          IconButton(
            tooltip: _landscape ? 'عرض عمودي' : 'عرض أفقي',
            icon: const Icon(Icons.screen_rotation),
            onPressed: _toggleOrientation,
          ),
          IconButton(
            tooltip: 'ملاءمة الشاشة',
            icon: const Icon(Icons.fit_screen),
            onPressed: () => setState(() => _view = _ViewRequest.fit),
          ),
          IconButton(
            tooltip: 'بحث في الخريطة',
            icon: const Icon(Icons.search),
            onPressed: () => _findInMap(root),
          ),
          IconButton(
            tooltip: 'حفظ الصورة في الجهاز',
            icon: const Icon(Icons.save_alt),
            onPressed: _saveImage,
          ),
          _menuButton(root),
        ],
      ),
    );
  }

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
        _currentRootId = rootId;

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
        final canvasW = math.max((acc - gapX) + pad * 2, _exporting ? 380.0 : 0.0);
        final footerH = _exporting ? 58.0 : 0.0;
        final canvasH = layout.height + pad * 2 + footerH;

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

        final viewer = LayoutBuilder(
          builder: (context, constraints) {
            final vw = constraints.maxWidth;
            final vh = constraints.maxHeight;
            final vp = Size(vw, vh);
            final viewportChanged = _lastViewport != null && _lastViewport != vp;
            _lastViewport = vp;

            final focus = _focusKey;
            var req = _view;
            if (viewportChanged && req == _ViewRequest.none && focus == null) {
              req = _ViewRequest.fit; // تدوير الشاشة: أعد الملاءمة
            }
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
                        if (_exporting)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: footerH,
                            child: buildCreditBar(height: footerH),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );

        if (widget.fullscreen) {
          return Scaffold(
            backgroundColor: Colors.white,
            body: Stack(
              children: [
                Positioned.fill(child: viewer),
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: _fullscreenBar(root),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

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
                tooltip: 'ملء الشاشة وتدوير',
                icon: const Icon(Icons.fullscreen),
                onPressed: _openFullscreen,
              ),
              IconButton(
                tooltip: 'حفظ الصورة في الجهاز',
                icon: const Icon(Icons.save_alt),
                onPressed: _saveImage,
              ),
              _menuButton(root),
            ],
          ),
          body: viewer,
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
