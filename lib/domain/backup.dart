import 'dart:convert';

import '../data/models/marriage.dart';
import '../data/models/person.dart';

class BackupException implements Exception {
  BackupException(this.errors);

  final List<String> errors;

  @override
  String toString() => errors.join('\n');
}

class BackupData {
  const BackupData({
    required this.persons,
    required this.marriages,
    this.exportedAt,
  });

  final List<Person> persons;
  final List<Marriage> marriages;
  final DateTime? exportedAt;
}

/// ترميز وفك ترميز النسخة الاحتياطية (JSON) مع تحقق كامل قبل أي كتابة.
class BackupCodec {
  BackupCodec._();

  static const String appId = 'family_tree';
  static const int formatVersion = 1;

  static String encode(
    List<Person> persons,
    List<Marriage> marriages, {
    DateTime? now,
  }) {
    return jsonEncode({
      'app': appId,
      'format': formatVersion,
      'exported_at': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'persons': persons.map((p) => p.toMap()).toList(),
      'marriages': marriages.map((m) => m.toMap()).toList(),
    });
  }

  static BackupData decode(String source) {
    Object? raw;
    try {
      raw = jsonDecode(source);
    } on FormatException {
      throw BackupException(['الملف ليس بصيغة JSON صالحة']);
    }
    if (raw is! Map || raw['app'] != appId) {
      throw BackupException(['الملف ليس نسخة احتياطية من «شجرة عائلتي»']);
    }
    final format = raw['format'];
    if (format is! int || format < 1) {
      throw BackupException(['رقم صيغة النسخة غير صالح']);
    }
    if (format > formatVersion) {
      throw BackupException(['النسخة أحدث من هذا التطبيق. حدّث التطبيق أولاً']);
    }
    final rawPersons = raw['persons'];
    final rawMarriages = raw['marriages'];
    if (rawPersons is! List || rawMarriages is! List) {
      throw BackupException(['بنية الملف غير مكتملة']);
    }

    final errors = <String>[];
    void err(String message) {
      if (errors.length < 10) errors.add(message);
    }

    // ───── الأشخاص ─────
    final persons = <Person>[];
    final ids = <int>{};
    for (var i = 0; i < rawPersons.length; i++) {
      final label = 'شخص رقم ${i + 1}';
      final e = rawPersons[i];
      if (e is! Map) {
        err('$label: ليس كائناً صالحاً');
        continue;
      }
      var ok = true;
      void bad(String m) {
        ok = false;
        err('$label: $m');
      }

      final id = e['id'];
      if (id is! int || id <= 0) {
        bad('معرّف غير صالح');
      } else if (!ids.add(id)) {
        bad('معرّف مكرر ($id)');
      }
      final name = e['name'];
      if (name is! String || name.trim().isEmpty) {
        bad('الاسم مفقود');
      }
      final gender = e['gender'];
      if (gender is! String || !Gender.values.any((g) => g.name == gender)) {
        bad('قيمة الجنس غير صالحة');
      }
      for (final key in ['father_id', 'mother_id']) {
        final v = e[key];
        if (v != null && v is! int) bad('الحقل $key غير صالح');
      }
      for (final key in [
        'birth_date',
        'death_date',
        'notes',
        'created_at',
        'updated_at',
      ]) {
        final v = e[key];
        if (v != null && v is! String) bad('الحقل $key غير صالح');
      }
      if (ok) {
        persons.add(Person.fromMap(Map<String, Object?>.from(e)));
      }
    }

    final byId = {for (final p in persons) p.id!: p};
    for (final p in persons) {
      for (final parent in [p.fatherId, p.motherId]) {
        if (parent == null) continue;
        if (parent == p.id) {
          err('«${p.name}»: الشخص والد/والدة نفسه');
        } else if (!byId.containsKey(parent)) {
          err('«${p.name}»: الأب/الأم رقم $parent غير موجود في الملف');
        }
      }
      if (p.fatherId != null && p.fatherId == p.motherId) {
        err('«${p.name}»: الأب والأم الشخص نفسه');
      }
    }

    // حلقات النسب
    final visitState = <int, int>{};
    bool visit(int id) {
      final s = visitState[id];
      if (s == 1) return true;
      if (s == 2) return false;
      visitState[id] = 1;
      final p = byId[id]!;
      for (final parent in [p.fatherId, p.motherId]) {
        if (parent != null &&
            parent != id &&
            byId.containsKey(parent) &&
            visit(parent)) {
          return true;
        }
      }
      visitState[id] = 2;
      return false;
    }

    for (final p in persons) {
      if (visit(p.id!)) {
        err('حلقة في النسب عند «${p.name}»');
        break;
      }
    }

    // ───── الزواج ─────
    final marriages = <Marriage>[];
    final marriageIds = <int>{};
    for (var i = 0; i < rawMarriages.length; i++) {
      final label = 'زواج رقم ${i + 1}';
      final e = rawMarriages[i];
      if (e is! Map) {
        err('$label: ليس كائناً صالحاً');
        continue;
      }
      var ok = true;
      void bad(String m) {
        ok = false;
        err('$label: $m');
      }

      final id = e['id'];
      if (id is! int || id <= 0) {
        bad('معرّف غير صالح');
      } else if (!marriageIds.add(id)) {
        bad('معرّف مكرر ($id)');
      }
      final a = e['person1_id'];
      final b = e['person2_id'];
      if (a is! int || b is! int) {
        bad('الزوجان غير محددين');
      } else {
        if (a == b) bad('زواج شخص من نفسه');
        if (!byId.containsKey(a) || !byId.containsKey(b)) {
          bad('أحد الزوجين غير موجود في الملف');
        }
      }
      final status = e['status'];
      if (status is! String ||
          !MarriageStatus.values.any((s) => s.name == status)) {
        bad('حالة الزواج غير صالحة');
      }
      for (final key in [
        'start_date',
        'end_date',
        'notes',
        'created_at',
        'updated_at',
      ]) {
        final v = e[key];
        if (v != null && v is! String) bad('الحقل $key غير صالح');
      }
      if (ok) {
        marriages.add(Marriage.fromMap(Map<String, Object?>.from(e)));
      }
    }

    if (errors.isNotEmpty) {
      throw BackupException(errors);
    }

    final exportedAt = raw['exported_at'];
    return BackupData(
      persons: persons,
      marriages: marriages,
      exportedAt: exportedAt is String ? DateTime.tryParse(exportedAt) : null,
    );
  }
}
