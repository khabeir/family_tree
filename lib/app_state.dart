import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'core/arabic_text.dart';
import 'data/models/marriage.dart';
import 'data/models/person.dart';
import 'data/repositories/marriage_repository.dart';
import 'data/repositories/person_repository.dart';
import 'domain/family_service.dart';

/// حالة التطبيق: نسخة مخزنة من الأشخاص في الذاكرة + عمليات الكتابة عبر FamilyService.
///
/// الحقل `name` في قاعدة البيانات هو الاسم الأول فقط. الاسم المعروض يُركَّب
/// تلقائياً بسلسلة الآباء (حتى [maxNameParts] أجزاء).
class AppState extends ChangeNotifier {
  AppState(this.db)
      : persons = PersonRepository(db),
        marriages = MarriageRepository(db) {
    service = FamilyService(persons, marriages);
  }

  static const int maxNameParts = 4;
  final Database db;

  final PersonRepository persons;
  final MarriageRepository marriages;
  late final FamilyService service;

  List<Person> _all = const [];
  Map<int, Person> _byId = const {};
  Map<int, String> _display = const {};
  List<Marriage> _marriages = const [];

  List<Marriage> get allMarriages => _marriages;

  List<Person> get all => _all;

  Person? byId(int? id) => id == null ? null : _byId[id];

  /// الاسم المعروض: الاسم الأول + أسماء الآباء (ثلاثي/رباعي إن وُجدوا).
  String displayName(Person p) => _display[p.id] ?? p.name;

  /// يركّب اسماً من [first] وسلسلة الآباء ابتداءً من [fatherId] (للمعاينة أثناء الإدخال).
  String composeName(String first, int? fatherId, {int? selfId}) {
    final parts = <String>[first.trim()];
    final seen = <int>{if (selfId != null) selfId};
    var next = fatherId;
    while (next != null && parts.length < maxNameParts && seen.add(next)) {
      final father = _byId[next];
      if (father == null) break;
      parts.add(father.name);
      next = father.fatherId;
    }
    return parts.where((s) => s.isNotEmpty).join(' ');
  }

  Future<void> load() async {
    final rows = await persons.getAll();
    _marriages = await marriages.getAll();
    _byId = {for (final p in rows) p.id!: p};
    _display = {
      for (final p in rows) p.id!: composeName(p.name, p.fatherId, selfId: p.id),
    };
    rows.sort((a, b) =>
        normalizeArabic(_display[a.id]!).compareTo(normalizeArabic(_display[b.id]!)));
    _all = rows;
    notifyListeners();
  }

  // ───── استعلامات ─────

  List<Person> search(String query) {
    final q = normalizeArabic(query);
    if (q.isEmpty) {
      return _all;
    }
    return _all
        .where((p) => normalizeArabic(displayName(p)).contains(q))
        .toList();
  }

  List<Person> childrenOf(int id) {
    final list =
        _all.where((p) => p.fatherId == id || p.motherId == id).toList();
    list.sort((a, b) {
      final x = a.birthDate;
      final y = b.birthDate;
      if (x != null && y != null && x != y) return x.compareTo(y);
      if (x != null && y == null) return -1;
      if (x == null && y != null) return 1;
      return a.id!.compareTo(b.id!);
    });
    return list;
  }

  String? parentsLabel(Person p) {
    final parts = <String>[];
    final father = byId(p.fatherId);
    final mother = byId(p.motherId);
    if (father != null) parts.add('الأب: ${displayName(father)}');
    if (mother != null) parts.add('الأم: ${displayName(mother)}');
    return parts.isEmpty ? null : parts.join(' • ');
  }

  Future<List<Marriage>> marriagesOf(int personId) =>
      marriages.getForPerson(personId);

  // ───── كتابة ─────

  Future<int> addPerson(Person p) async {
    final id = await service.addPerson(p);
    await load();
    return id;
  }

  Future<bool> updatePerson(Person p) async {
    final ok = await service.updatePerson(p);
    await load();
    return ok;
  }

  Future<bool> deletePerson(int id) async {
    final ok = await service.deletePerson(id);
    await load();
    return ok;
  }

  Future<int> addMarriage(Marriage m) async {
    final id = await service.addMarriage(m);
    _marriages = await marriages.getAll();
    notifyListeners();
    return id;
  }

  Future<bool> updateMarriage(Marriage m) async {
    final ok = await service.updateMarriage(m);
    _marriages = await marriages.getAll();
    notifyListeners();
    return ok;
  }

  Future<bool> deleteMarriage(int id) async {
    final ok = await service.deleteMarriage(id);
    _marriages = await marriages.getAll();
    notifyListeners();
    return ok;
  }
}
