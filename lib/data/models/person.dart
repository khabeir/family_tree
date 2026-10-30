const Object _unset = Object();

enum Gender {
  male,
  female,
  unknown;

  static Gender parse(String? value) => Gender.values.firstWhere(
        (g) => g.name == value,
        orElse: () => Gender.unknown,
      );
}

class Person {
  const Person({
    this.id,
    required this.name,
    this.gender = Gender.unknown,
    this.fatherId,
    this.motherId,
    this.birthDate,
    this.deathDate,
    this.notes,
    this.sortOrder = 0,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final Gender gender;
  final int? fatherId;
  final int? motherId;

  /// تاريخ بصيغة yyyy-MM-dd
  final String? birthDate;
  final String? deathDate;
  final String? notes;

  /// ترتيب الظهور بين الإخوة (الأصغر أولاً). 0 = لم يُعيَّن بعد (يُعيَّن عند الحفظ).
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Person copyWith({
    int? id,
    String? name,
    Gender? gender,
    Object? fatherId = _unset,
    Object? motherId = _unset,
    Object? birthDate = _unset,
    Object? deathDate = _unset,
    Object? notes = _unset,
    int? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Person(
      id: id ?? this.id,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      fatherId: identical(fatherId, _unset) ? this.fatherId : fatherId as int?,
      motherId: identical(motherId, _unset) ? this.motherId : motherId as int?,
      birthDate:
          identical(birthDate, _unset) ? this.birthDate : birthDate as String?,
      deathDate:
          identical(deathDate, _unset) ? this.deathDate : deathDate as String?,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'gender': gender.name,
        'father_id': fatherId,
        'mother_id': motherId,
        'birth_date': birthDate,
        'death_date': deathDate,
        'notes': notes,
        'sort_order': sortOrder,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
      };

  factory Person.fromMap(Map<String, Object?> map) => Person(
        id: map['id'] as int?,
        name: map['name'] as String,
        gender: Gender.parse(map['gender'] as String?),
        fatherId: map['father_id'] as int?,
        motherId: map['mother_id'] as int?,
        birthDate: map['birth_date'] as String?,
        deathDate: map['death_date'] as String?,
        notes: map['notes'] as String?,
        sortOrder: map['sort_order'] is int ? map['sort_order'] as int : 0,
        createdAt: DateTime.tryParse((map['created_at'] as String?) ?? ''),
        updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? ''),
      );

  @override
  String toString() => 'Person(id: $id, name: $name)';
}
