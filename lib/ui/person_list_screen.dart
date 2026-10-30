import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/models/person.dart';
import 'access_gate.dart';
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

  Widget _banner(
    BuildContext context,
    int total,
    int males,
    int females,
    int marriages,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final on = scheme.onPrimary;

    Widget mini(IconData icon, String label, int value) {
      return Expanded(
        child: Column(
          children: [
            Icon(icon, color: on, size: 20),
            const SizedBox(height: 2),
            Text(
              '$value',
              style: TextStyle(
                color: on,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(color: on, fontSize: 11),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [scheme.primary, scheme.tertiary],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total',
                  style: TextStyle(
                    color: on,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'فرداً في شجرة العائلة',
                  style: TextStyle(color: on),
                ),
              ],
            ),
          ),
          mini(Icons.man, 'ذكور', males),
          mini(Icons.woman, 'إناث', females),
          mini(Icons.favorite, 'زيجات', marriages),
        ],
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
              MaterialPageRoute(builder: (_) => Gated(child: ImportScreen(state: state))),
            ),
          ),
          IconButton(
            tooltip: 'النسخ الاحتياطي والبيانات',
            icon: const Icon(Icons.save_alt),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => Gated(child: BackupScreen(state: state))),
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
              _banner(context, all.length, males, females,
                  state.allMarriages.length),
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
