#!/usr/bin/env bash
# شجرة عائلتي - المرحلة 3: الشجرة التفاعلية
# شغّله من جذر المستودع: bash setup_phase3.sh
set -euo pipefail

mkdir -p lib/domain lib/ui test

# ───────────────────────── منطق الشجرة (Dart صرف قابل للاختبار) ─────────────────────────
cat > lib/domain/family_tree_index.dart <<'DART_EOF'
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
      list.sort((a, b) => a.id!.compareTo(b.id!));
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
DART_EOF

# ───────────────────────── شاشة الشجرة ─────────────────────────
cat > lib/ui/tree_screen.dart <<'DART_EOF'
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/family_tree_index.dart';
import 'person_detail_screen.dart';
import 'ui_helpers.dart';

class TreeScreen extends StatefulWidget {
  const TreeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<TreeScreen> createState() => _TreeScreenState();
}

class _TreeScreenState extends State<TreeScreen> {
  final _controller = TextEditingController();
  String _query = '';
  late final Set<int> _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = {
      for (final r in FamilyTreeIndex(widget.state.all).roots) r.id!,
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle(int id) {
    setState(() {
      if (!_expanded.remove(id)) {
        _expanded.add(id);
      }
    });
  }

  Widget _row(BuildContext context, TreeRow r, bool searching) {
    final state = widget.state;
    final p = r.person;
    final theme = Theme.of(context);
    final indent = 8 + math.min(r.depth, 14) * 20.0;
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PersonDetailScreen(state: state, personId: p.id!),
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
            start: indent, end: 8, top: 2, bottom: 2),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: r.hasVisibleChildren
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: r.expanded ? 'إغلاق الفرع' : 'فتح الفرع',
                      icon: Icon(r.expanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_left),
                      onPressed: searching ? null : () => _toggle(p.id!),
                    )
                  : null,
            ),
            Icon(genderIcon(p.gender), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.displayName(p),
                style: r.isMatch
                    ? TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      )
                    : null,
              ),
            ),
            if (r.childCount > 0)
              Text(
                '${r.childCount}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final index = FamilyTreeIndex(widget.state.all);
        final searching = _query.trim().isNotEmpty;
        Set<int>? visible;
        var matches = <int>{};
        if (searching) {
          matches = widget.state.search(_query).map((p) => p.id!).toSet();
          visible = index.withAncestors(matches);
        }
        final rows = index.flatten(
          expanded: _expanded,
          visible: visible,
          matches: matches,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('شجرة النسب'),
            actions: [
              IconButton(
                tooltip: 'فتح كل الفروع',
                icon: const Icon(Icons.unfold_more),
                onPressed: () => setState(() {
                  _expanded
                    ..clear()
                    ..addAll(index.expandableIds);
                }),
              ),
              IconButton(
                tooltip: 'إغلاق كل الفروع',
                icon: const Icon(Icons.unfold_less),
                onPressed: () => setState(_expanded.clear),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'ابحث في الشجرة بالاسم',
                    border: const OutlineInputBorder(),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(widget.state.all.isEmpty
                            ? 'لا يوجد أفراد بعد.'
                            : 'لا نتائج مطابقة'),
                      )
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, i) =>
                            _row(context, rows[i], searching),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
DART_EOF

# ───────────────────────── الشاشة الرئيسية بتبويبين ─────────────────────────
cat > lib/ui/home_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
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
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: 'الأفراد'),
          NavigationDestination(icon: Icon(Icons.account_tree), label: 'الشجرة'),
        ],
      ),
    );
  }
}
DART_EOF

# ───────────────────────── ربط الشاشة الرئيسية ─────────────────────────
sed -i "s|import 'ui/person_list_screen.dart';|import 'ui/home_screen.dart';|" lib/main.dart
sed -i "s|home: PersonListScreen(state: state),|home: HomeScreen(state: state),|" lib/main.dart
grep -q "import 'ui/home_screen.dart';" lib/main.dart
grep -q "home: HomeScreen(state: state)," lib/main.dart

# ───────────────────────── الاختبارات ─────────────────────────
cat > test/family_tree_index_test.dart <<'DART_EOF'
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
DART_EOF

echo "تم إنشاء ملفات المرحلة 3."
