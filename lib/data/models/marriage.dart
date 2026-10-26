const Object _unset = Object();

enum MarriageStatus {
  married,
  divorced,
  widowed;

  static MarriageStatus parse(String? value) => MarriageStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => MarriageStatus.married,
      );
}

class Marriage {
  const Marriage({
    this.id,
    required this.person1Id,
    required this.person2Id,
    this.startDate,
    this.endDate,
    this.status = MarriageStatus.married,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final int? id;
  final int person1Id;
  final int person2Id;
  final String? startDate;
  final String? endDate;
  final MarriageStatus status;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Marriage copyWith({
    int? id,
    int? person1Id,
    int? person2Id,
    Object? startDate = _unset,
    Object? endDate = _unset,
    MarriageStatus? status,
    Object? notes = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Marriage(
      id: id ?? this.id,
      person1Id: person1Id ?? this.person1Id,
      person2Id: person2Id ?? this.person2Id,
      startDate:
          identical(startDate, _unset) ? this.startDate : startDate as String?,
      endDate: identical(endDate, _unset) ? this.endDate : endDate as String?,
      status: status ?? this.status,
      notes: identical(notes, _unset) ? this.notes : notes as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'person1_id': person1Id,
        'person2_id': person2Id,
        'start_date': startDate,
        'end_date': endDate,
        'status': status.name,
        'notes': notes,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'updated_at': updatedAt?.toUtc().toIso8601String(),
      };

  factory Marriage.fromMap(Map<String, Object?> map) => Marriage(
        id: map['id'] as int?,
        person1Id: map['person1_id'] as int,
        person2Id: map['person2_id'] as int,
        startDate: map['start_date'] as String?,
        endDate: map['end_date'] as String?,
        status: MarriageStatus.parse(map['status'] as String?),
        notes: map['notes'] as String?,
        createdAt: DateTime.tryParse((map['created_at'] as String?) ?? ''),
        updatedAt: DateTime.tryParse((map['updated_at'] as String?) ?? ''),
      );
}
