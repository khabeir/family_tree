import 'package:family_tree/ui/about_screen.dart';
import 'package:family_tree/ui/app_info.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('شاشة حول البرنامج تعرض الاسم وعنوان الصفحة', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    expect(find.text('حول البرنامج'), findsOneWidget);
    expect(find.text(kAppName), findsOneWidget);
    expect(find.text('عن البرنامج'), findsOneWidget);
  });

  test('ثوابت المعلومات', () {
    expect(kAppName, 'شجرة عائلتي');
    expect(kAppVersion, isNotEmpty);
  });
}
