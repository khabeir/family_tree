import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:family_tree/ui/image_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FHD: أطول ضلع 1920 بكسل على الأقل وبمعامل لا يقل عن 2', () {
    const size = Size(1000, 800);
    final r = ImageQuality.fhd.ratioFor(size);
    expect(r, greaterThanOrEqualTo(2.0));
    expect(size.width * r, greaterThanOrEqualTo(1920));
  });

  test('اللوحة الصغيرة تُكبَّر لتبلغ الحد الأدنى للضلع', () {
    final r = ImageQuality.standard.ratioFor(const Size(600, 400));
    expect(600 * r, closeTo(1280, 0.5));
    final r4k = ImageQuality.uhd.ratioFor(const Size(1000, 800));
    expect(1000 * r4k, closeTo(3840, 0.5));
  });

  test('الجودة تتزايد: عادية ≤ FHD ≤ 4K', () {
    const size = Size(900, 700);
    final a = ImageQuality.standard.ratioFor(size);
    final b = ImageQuality.fhd.ratioFor(size);
    final c = ImageQuality.uhd.ratioFor(size);
    expect(a, lessThanOrEqualTo(b));
    expect(b, lessThanOrEqualTo(c));
  });

  test('الخرائط الضخمة محدودة بالضلع الأقصى وعدد البكسلات', () {
    for (final q in ImageQuality.values) {
      const size = Size(6000, 4000);
      final r = q.ratioFor(size);
      expect(math.max(size.width, size.height) * r,
          lessThanOrEqualTo(ImageQuality.maxSide + 0.5));
      expect(size.width * size.height * r * r,
          lessThanOrEqualTo(ImageQuality.maxPixels + 1));
      expect(r, greaterThan(0));
    }
  });
}
