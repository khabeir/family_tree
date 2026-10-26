import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/person.dart';
import 'ui_helpers.dart';

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
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث بالاسم',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('لا نتائج'))
                : ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final p = items[i];
                      return ListTile(
                        leading: Icon(genderIcon(p.gender)),
                        title: Text(p.name),
                        subtitle: widget.state.parentsLabel(p) == null
                            ? null
                            : Text(widget.state.parentsLabel(p)!),
                        onTap: () => Navigator.of(context).pop(p),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
