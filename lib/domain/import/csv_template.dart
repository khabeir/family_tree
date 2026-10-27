import '../../data/models/person.dart';
import '../sample_data.dart';
import 'table_reader.dart';

/// قالب CSV بالأعمدة المدعومة، مملوء بالعائلة التجريبية الوهمية لتعرف الشكل المطلوب.
String templateCsv() {
  final s = sampleFamily();
  final spouseOf = <int, int>{};
  for (final m in s.marriages) {
    spouseOf.putIfAbsent(m.person1Id, () => m.person2Id);
    spouseOf.putIfAbsent(m.person2Id, () => m.person1Id);
  }
  String g(Gender x) => x == Gender.male ? 'ذكر' : (x == Gender.female ? 'أنثى' : '');
  return toCsv([
    ['المعرّف', 'الاسم', 'الجنس', 'معرّف الأب', 'معرّف الأم', 'الزوج/الزوجة', 'ملاحظات'],
    for (final p in s.persons)
      [
        '${p.id}',
        p.name,
        g(p.gender),
        p.fatherId == null ? '' : '${p.fatherId}',
        p.motherId == null ? '' : '${p.motherId}',
        spouseOf[p.id] == null ? '' : '${spouseOf[p.id]}',
        '',
      ],
  ]);
}
