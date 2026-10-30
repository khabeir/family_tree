import 'package:family_tree/ui/branding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('نص حقوق التصميم: الاسم ثم رقم الهاتف', () {
    expect(kCreditText, startsWith('©'));
    expect(kCreditText, contains('محمد برير حبيب الله'));
    expect(kCreditText, contains('0914111214'));
    expect(
      kCreditText.indexOf('0914111214'),
      greaterThan(kCreditText.indexOf('محمد برير حبيب الله')),
    );
  });

  test('تاريخ التصدير بصيغة yyyy-MM-dd مع أصفار بادئة', () {
    expect(exportDateText(DateTime(2026, 10, 30)), 'تاريخ التصدير: 2026-10-30');
    expect(exportDateText(DateTime(2026, 1, 5)), 'تاريخ التصدير: 2026-01-05');
  });
}
