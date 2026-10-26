import 'package:family_tree/core/arabic_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('يوحّد الهمزات والتاء المربوطة والتشكيل', () {
    expect(normalizeArabic('أَحمد'), normalizeArabic('احمد'));
    expect(normalizeArabic('إبراهيم'), normalizeArabic('ابراهيم'));
    expect(normalizeArabic('فاطمة'), normalizeArabic('فاطمه'));
    expect(normalizeArabic('موسى'), normalizeArabic('موسي'));
  });

  test('يضغط المسافات ويقصّ الأطراف', () {
    expect(normalizeArabic('  محمد    علي '), 'محمد علي');
  });
}
