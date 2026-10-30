import 'package:family_tree/ui/branding.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('نص حقوق التصميم يحتوي الاسم الصحيح', () {
    expect(kCreditText, contains('محمد برير حبيب الله'));
    expect(kCreditText, startsWith('©'));
  });
}
