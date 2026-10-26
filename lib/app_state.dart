import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'core/arabic_text.dart';
import 'data/models/marriage.dart';
import 'data/models/person.dart';
import 'data/repositories/marriage_repository.dart';
import 'data/repositories/person_repository.dart';
import 'domain/family_service.dart';

/// حالة التطبيق: نسخة مخزنة من الأشخاص في الذاكرة + عمليات الكتابة عبر FamilyService.
class AppState extends ChangeNotifier {
  AppState(Database db)
      : persons = PersonRepository(db),
        marriages = MarriageRepository(db) {
    service = FamilyService(persons, marriages);
  }

  final PersonRepository persons;
  final MarriageRepository marriages;
  late final FamilyService service;

  List<Person> _all = const [];
  Map<int, Person> _byId = const {};

  List<Person> get all => _all;

  Person? byId(int? id) => id == null ? null : _byId[id];

  Future<void> load() async {
    _all = await persons.getAll();
    _byId = {for (final p in _all) p.id!: p};
    notifyListeners();
  }

  // ───── استعلامات ─────

  List<Person> search(String query) {
    final q = normalizeArabic(query);
    if (q.isEmpty) {
      return _all;
    }
    return _all.where((p) => normalizeArabic(p.name).contains(q)).toList();
  }

  List<Person> childrenOf(int id) {
    final list =
        _all.where((p) => p.fatherId == id || p.motherId == id).toList();
    list.sort((a, b) {
      final x = a.birthDate;
      final y = b.birthDate;
      if (x == null && y == null) return a.name.compareTo(b.name);
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
    return list;
  }

  String? parentsLabel(Person p) {
    final parts = <String>[];
    final father = byId(p.fatherId);
    final mother = byId(p.motherId);
    if (father != null) parts.add('الأب: ${father.name}');
    if (mother != null) parts.add('الأم: ${mother.name}');
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
    notifyListeners();
    return id;
  }

  Future<bool> updateMarriage(Marriage m) async {
    final ok = await service.updateMarriage(m);
    notifyListeners();
    return ok;
  }

  Future<bool> deleteMarriage(int id) async {
    final ok = await service.deleteMarriage(id);
    notifyListeners();
    return ok;
  }
}
