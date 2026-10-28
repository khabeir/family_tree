import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/person.dart';
import 'backup_screen.dart';
import 'import_screen.dart';
import 'person_detail_screen.dart';
import 'person_form_screen.dart';
import 'widgets.dart';

class PersonListScreen extends StatefulWidget {
  const PersonListScreen({super.key, required this.state});

  final AppState state;

  @override
  State<PersonListScreen> createState() => _PersonListScreenState();
}

class _PersonListScreenState extends State<PersonListScreen> {
  final _controller = TextEditingController();
  String _query = '';
  Gender? _gender;

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

  Widget _stat(BuildContext context, IconData icon, String label, int value,
      Color color) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Icon(icon, size: 20, color: color),
            Text('$value',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('شجرة عائلتي'),
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
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final all = state.all;
          final males = all.where((p) => p.gender == Gender.male).length;
          final females = all.where((p) => p.gender == Gender.female).length;
          final items = state
              .search(_query)
              .where((p) => _gender == null || p.gender == _gender)
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: _stat(context, Icons.groups, 'الأفراد', all.length,
                          Theme.of(context).colorScheme.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(context, Icons.man, 'ذكور', males,
                          Colors.blue.shade700),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(context, Icons.woman, 'إناث', females,
                          Colors.pink.shade600),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _stat(context, Icons.favorite, 'الزيجات',
                          state.allMarriages.length, Colors.red.shade400),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'ابحث بالاسم (يعمل على الاسم الكامل)',
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    for (final entry in <(String, Gender?)>[
                      ('الكل', null),
                      ('ذكور', Gender.male),
                      ('إناث', Gender.female),
                    ]) ...[
                      ChoiceChip(
                        label: Text(entry.$1),
                        selected: _gender == entry.$2,
                        onSelected: (_) => setState(() => _gender = entry.$2),
                      ),
                      const SizedBox(width: 8),
                    ],
                    const Spacer(),
                    Text('${items.length} نتيجة',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: items.isEmpty
                    ? EmptyState(
                        icon: all.isEmpty
                            ? Icons.family_restroom
                            : Icons.search_off,
                        message: all.isEmpty
                            ? 'لا يوجد أفراد بعد.\nأضف أول شخص، أو حمّل بيانات تجريبية من أيقونة النسخ الاحتياطي.'
                            : 'لا نتائج مطابقة',
                        action: all.isEmpty
                            ? FilledButton.icon(
                                onPressed: _add,
                                icon: const Icon(Icons.person_add),
                                label: const Text('إضافة شخص'),
                              )
                            : null,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final p = items[i];
                          final parents = state.parentsLabel(p);
                          final kids = state.childrenOf(p.id!).length;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Card(
                              child: ListTile(
                                leading: PersonAvatar(gender: p.gender),
                                title: Text(
                                  state.displayName(p),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                subtitle: parents == null ? null : Text(parents),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (kids > 0) ...[
                                      const Icon(Icons.child_care, size: 16),
                                      const SizedBox(width: 2),
                                      Text('$kids'),
                                      const SizedBox(width: 4),
                                    ],
                                    const Icon(Icons.chevron_left),
                                  ],
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PersonDetailScreen(
                                      state: state,
                                      personId: p.id!,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add),
        label: const Text('إضافة شخص'),
      ),
    );
  }
}
