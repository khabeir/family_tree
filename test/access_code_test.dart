import 'package:family_tree/domain/access_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('الكود = اليوم × 999 × الشهر', () {
    expect(unlockCodeFor(DateTime(2026, 10, 30)), 299700); // 30*999*10
    expect(unlockCodeFor(DateTime(2026, 1, 1)), 999);
    expect(unlockCodeFor(DateTime(2026, 12, 31)), 371628); // 31*999*12
  });

  test('قبول الكود الصحيح بصيغ مختلفة', () {
    final d = DateTime(2026, 10, 30);
    expect(isValidUnlockCode('299700', d), isTrue);
    expect(isValidUnlockCode(' 299700 ', d), isTrue);
    expect(isValidUnlockCode('299,700', d), isTrue);
    expect(isValidUnlockCode('٢٩٩٧٠٠', d), isTrue); // أرقام عربية
    expect(isValidUnlockCode('۲۹۹۷۰۰', d), isTrue); // أرقام فارسية
  });

  test('رفض الكود الخاطئ أو الفارغ أو بحروف', () {
    final d = DateTime(2026, 10, 30);
    expect(isValidUnlockCode('', d), isFalse);
    expect(isValidUnlockCode('299701', d), isFalse);
    expect(isValidUnlockCode('abc', d), isFalse);
    expect(isValidUnlockCode('29a9700', d), isFalse);
    expect(isValidUnlockCode('-299700', d), isFalse);
  });

  test('كود يوم لا يصلح ليوم آخر', () {
    expect(isValidUnlockCode('299700', DateTime(2026, 10, 31)), isFalse);
    expect(isValidUnlockCode('299700', DateTime(2026, 10, 30)), isTrue);
  });
}
