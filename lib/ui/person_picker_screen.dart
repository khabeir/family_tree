import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/person.dart';
import 'widgets.dart';

class PersonPickerScreen extends StatefulWidget {
  const PersonPickerScreen({
    super.key,
    required this.state,
    required this.title,
    this.excludeId,
    this.excludeGender,
  });

  final AppState state;
  final String title;
  final int? excludeId;
  final Gender? excludeGender;

  @override
  State<PersonPickerScreen> createState() => _PersonPickerScreenState();
}

class _PersonPickerScreenState extends State<PersonPickerScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final items = widget.state
        .search(_query)
        .where((p) =>
            p.id != widget.excludeId &&
            (widget.excludeGender == null || p.gender != widget.excludeGender))
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'ابحث بالاسم',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(icon: Icons.search_off, message: 'لا نتائج')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final p = items[i];
                      final parents = widget.state.parentsLabel(p);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Card(
                          child: ListTile(
                            leading: PersonAvatar(gender: p.gender),
                            title: Text(widget.state.displayName(p)),
                            subtitle: parents == null ? null : Text(parents),
                            onTap: () => Navigator.of(context).pop(p),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
