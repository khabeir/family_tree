import '../data/models/marriage.dart';
import '../data/models/person.dart';
import '../data/repositories/marriage_repository.dart';
import '../data/repositories/person_repository.dart';

class FamilyValidationException implements Exception {
  FamilyValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// قواعد الأعمال: التحقق من الأسماء والتواريخ والوالدين ومنع الحلقات والتكرار.
class FamilyService {
  FamilyService(this._persons, this._marriages);

  final PersonRepository _persons;
  final MarriageRepository _marriages;

  // ───── الأشخاص ─────

  Future<int> addPerson(Person person) async {
    final cleaned = _clean(person);
    await _validatePerson(cleaned);
    return _persons.insert(cleaned);
  }

  /// يعيد false إذا لم يكن الشخص موجوداً.
  Future<bool> updatePerson(Person person) async {
    final id = person.id;
    if (id == null) {
      throw FamilyValidationException('معرّف الشخص مطلوب للتعديل');
    }
    if (await _persons.getById(id) == null) {
      return false;
    }
    final cleaned = _clean(person);
    await _validatePerson(cleaned);
    return _persons.update(cleaned);
  }

  /// الحذف يفرغ حقول الأب/الأم عند الأبناء ويحذف علاقات الزواج (قيود قاعدة البيانات).
  Future<bool> deletePerson(int id) => _persons.delete(id);

  Person _clean(Person p) => p.copyWith(
        name: p.name.trim().replaceAll(RegExp(r'\s+'), ' '),
        notes: (p.notes == null || p.notes!.trim().isEmpty)
            ? null
            : p.notes!.trim(),
      );

  Future<void> _validatePerson(Person p) async {
    if (p.name.isEmpty) {
      throw FamilyValidationException('الاسم مطلوب');
    }
    if (p.name.length > 200) {
      throw FamilyValidationException('الاسم أطول من 200 حرف');
    }
    _checkDate(p.birthDate, 'تاريخ الميلاد');
    _checkDate(p.deathDate, 'تاريخ الوفاة');
    if (p.birthDate != null &&
        p.deathDate != null &&
        p.deathDate!.compareTo(p.birthDate!) < 0) {
      throw FamilyValidationException('تاريخ الوفاة قبل تاريخ الميلاد');
    }

    final id = p.id;
    if (id != null && (p.fatherId == id || p.motherId == id)) {
      throw FamilyValidationException('لا يمكن أن يكون الشخص أباً أو أماً لنفسه');
    }
    if (p.fatherId != null && p.fatherId == p.motherId) {
      throw FamilyValidationException('الأب والأم لا يمكن أن يكونا الشخص نفسه');
    }

    if (p.fatherId != null) {
      final father = await _persons.getById(p.fatherId!);
      if (father == null) {
        throw FamilyValidationException('الأب غير موجود');
      }
      if (father.gender == Gender.female) {
        throw FamilyValidationException('الأب المختار مسجّل أنثى');
      }
    }
    if (p.motherId != null) {
      final mother = await _persons.getById(p.motherId!);
      if (mother == null) {
        throw FamilyValidationException('الأم غير موجودة');
      }
      if (mother.gender == Gender.male) {
        throw FamilyValidationException('الأم المختارة مسجّلة ذكراً');
      }
    }

    if (id != null) {
      for (final parentId in [p.fatherId, p.motherId]) {
        if (parentId != null && await _isAncestorOrSelf(id, of: parentId)) {
          throw FamilyValidationException(
              'هذا الاختيار ينشئ حلقة في النسب (الشخص من أجداد والديه)');
        }
      }
      final children = await _persons.getChildren(id);
      if (p.gender == Gender.male && children.any((c) => c.motherId == id)) {
        throw FamilyValidationException('لا يمكن جعله ذكراً وهو أم لأحد الأبناء');
      }
      if (p.gender == Gender.female && children.any((c) => c.fatherId == id)) {
        throw FamilyValidationException('لا يمكن جعلها أنثى وهي أب لأحد الأبناء');
      }
    }
  }

  /// هل [candidateId] هو [of] نفسه أو أحد أسلافه؟
  Future<bool> _isAncestorOrSelf(int candidateId, {required int of}) async {
    final visited = <int>{};
    final queue = <int>[of];
    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      if (current == candidateId) {
        return true;
      }
      if (!visited.add(current)) {
        continue;
      }
      final person = await _persons.getById(current);
      if (person == null) {
        continue;
      }
      if (person.fatherId != null) queue.add(person.fatherId!);
      if (person.motherId != null) queue.add(person.motherId!);
    }
    return false;
  }

  // ───── الزواج ─────

  Future<int> addMarriage(Marriage marriage) async {
    await _validateMarriage(marriage);
    return _marriages.insert(marriage);
  }

  Future<bool> updateMarriage(Marriage marriage) async {
    final id = marriage.id;
    if (id == null) {
      throw FamilyValidationException('معرّف العلاقة مطلوب للتعديل');
    }
    if (await _marriages.getById(id) == null) {
      return false;
    }
    await _validateMarriage(marriage);
    return _marriages.update(marriage);
  }

  Future<bool> deleteMarriage(int id) => _marriages.delete(id);

  Future<void> _validateMarriage(Marriage m) async {
    if (m.person1Id == m.person2Id) {
      throw FamilyValidationException('لا يمكن تسجيل زواج شخص من نفسه');
    }
    if (await _persons.getById(m.person1Id) == null ||
        await _persons.getById(m.person2Id) == null) {
      throw FamilyValidationException('أحد الزوجين غير موجود');
    }
    _checkDate(m.startDate, 'تاريخ الزواج');
    _checkDate(m.endDate, 'تاريخ انتهاء الزواج');
    if (m.startDate != null &&
        m.endDate != null &&
        m.endDate!.compareTo(m.startDate!) < 0) {
      throw FamilyValidationException('تاريخ الانتهاء قبل تاريخ الزواج');
    }
    if (m.status == MarriageStatus.married) {
      final existing = await _marriages.findBetween(m.person1Id, m.person2Id);
      final duplicate = existing.any(
          (e) => e.id != m.id && e.status == MarriageStatus.married);
      if (duplicate) {
        throw FamilyValidationException('يوجد زواج قائم مسجّل بين هذين الشخصين');
      }
    }
  }

  // ───── أدوات ─────

  void _checkDate(String? value, String label) {
    if (value == null) {
      return;
    }
    final parsed = DateTime.tryParse(value);
    final valid = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value) &&
        parsed != null &&
        parsed.toIso8601String().startsWith(value);
    if (!valid) {
      throw FamilyValidationException('$label غير صالح (الصيغة yyyy-MM-dd)');
    }
  }
}
