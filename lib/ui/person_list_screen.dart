import 'package:flutter/material.dart';

import '../app_state.dart';
import 'person_detail_screen.dart';
import 'person_form_screen.dart';
import 'backup_screen.dart';
import 'import_screen.dart';
import 'ui_helpers.dart';

class PersonListScreen extends StatefulWidget {
  const PersonListScreen({super.key, required this.state});

  final AppState state;

  @override
  State<PersonListScreen> createState() => _PersonListScreenState();
}

class _PersonListScreenState extends State<PersonListScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PersonFormScreen(state: widget.state),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'استيراد Excel / CSV',
            icon: const Icon(Icons.table_chart),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ImportScreen(state: state)),
            ),
          ),
          IconButton(
            tooltip: 'النسخ الاحتياطي والبيانات',
            icon: const Icon(Icons.save_alt),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => BackupScreen(state: state)),
            ),
          ),
        ],
        title: ListenableBuilder(
          listenable: state,
          builder: (context, _) => Text('شجرة عائلتي (${state.all.length})'),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'ابحث بالاسم',
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
            child: ListenableBuilder(
              listenable: state,
              builder: (context, _) {
                final items = state.search(_query);
                if (items.isEmpty) {
                  return Center(
                    child: Text(state.all.isEmpty
                        ? 'لا يوجد أفراد بعد. اضغط «إضافة شخص».'
                        : 'لا نتائج مطابقة'),
                  );
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final p = items[i];
                    final parents = state.parentsLabel(p);
                    return ListTile(
                      leading: CircleAvatar(child: Icon(genderIcon(p.gender))),
                      title: Text(state.displayName(p)),
                      subtitle: parents == null ? null : Text(parents),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PersonDetailScreen(
                            state: state,
                            personId: p.id!,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة شخص'),
      ),
    );
  }
}
