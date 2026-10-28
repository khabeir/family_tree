import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../domain/family_tree_index.dart';
import 'person_detail_screen.dart';
import 'widgets.dart';

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
    final scheme = theme.colorScheme;
    final depth = math.min(r.depth, 14);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PersonDetailScreen(state: state, personId: p.id!),
        ),
      ),
      child: Container(
        height: 48,
        padding: const EdgeInsetsDirectional.only(start: 8, end: 10),
        color: r.isMatch ? scheme.primaryContainer.withAlpha(120) : null,
        child: Row(
          children: [
            // خطوط عمودية رفيعة تُظهر عمق الجيل
            for (var d = 0; d < depth; d++)
              Container(
                width: 20,
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    end: BorderSide(color: scheme.outlineVariant),
                  ),
                ),
              ),
            SizedBox(
              width: 36,
              height: 36,
              child: r.hasVisibleChildren
                  ? IconButton(
                      padding: EdgeInsets.zero,
                      tooltip: r.expanded ? 'إغلاق الفرع' : 'فتح الفرع',
                      icon: Icon(
                        r.expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_left,
                        color: scheme.primary,
                      ),
                      onPressed: searching ? null : () => _toggle(p.id!),
                    )
                  : null,
            ),
            PersonAvatar(gender: p.gender, radius: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                state.displayName(p),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: r.isMatch
                    ? TextStyle(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      )
                    : null,
              ),
            ),
            if (r.childCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${r.childCount}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide.none,
                    ),
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
                    ? EmptyState(
                        icon: widget.state.all.isEmpty
                            ? Icons.account_tree_outlined
                            : Icons.search_off,
                        message: widget.state.all.isEmpty
                            ? 'لا يوجد أفراد بعد.'
                            : 'لا نتائج مطابقة',
                      )
                    : ListView.builder(
                        itemCount: rows.length,
                        itemExtent: 48,
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
