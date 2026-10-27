import '../data/models/marriage.dart';
import '../data/models/person.dart';
import 'backup.dart';

/// عائلة وهمية من 4 أجيال لتجربة الشجرة والخريطة. لا تمثل أشخاصاً حقيقيين.
BackupData sampleFamily() {
  final t = DateTime.utc(2024, 1, 1);
  Person p(int id, String name, Gender g, {int? f, int? m}) => Person(
        id: id,
        name: name,
        gender: g,
        fatherId: f,
        motherId: m,
        createdAt: t,
        updatedAt: t,
      );
  Marriage mar(int id, int a, int b,
          {MarriageStatus s = MarriageStatus.married}) =>
      Marriage(
        id: id,
        person1Id: a,
        person2Id: b,
        status: s,
        createdAt: t,
        updatedAt: t,
      );

  const male = Gender.male;
  const female = Gender.female;
  return BackupData(
    persons: [
      p(1, 'سالم', male),
      p(2, 'آمنة', female),
      p(3, 'خالد', male, f: 1, m: 2),
      p(4, 'مريم', female, f: 1, m: 2),
      p(5, 'يوسف', male, f: 1, m: 2),
      p(6, 'هدى', female),
      p(7, 'عمر', male),
      p(8, 'أحمد', male, f: 3, m: 6),
      p(9, 'سارة', female, f: 3, m: 6),
      p(10, 'ليلى', female, f: 3, m: 6),
      p(11, 'زياد', male, f: 7, m: 4),
      p(12, 'نور', female, f: 7, m: 4),
      p(13, 'رنا', female),
      p(14, 'كريم', male, f: 5, m: 13),
      p(15, 'دانة', female),
      p(16, 'ياسر', male, f: 8, m: 15),
      p(17, 'فاطمة', female),
      p(18, 'بلال', male, f: 1, m: 17),
    ],
    marriages: [
      mar(1, 1, 2),
      mar(2, 3, 6),
      mar(3, 4, 7),
      mar(4, 5, 13),
      mar(5, 8, 15),
      mar(6, 1, 17, s: MarriageStatus.divorced),
    ],
  );
}
