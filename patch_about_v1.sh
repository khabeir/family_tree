#!/usr/bin/env bash
# شجرة عائلتي - صفحة «حول البرنامج» (تبويب رابع)
# شغّله من جذر المستودع بعد patch_credit_phone_v1.sh: bash patch_about_v1.sh
set -euo pipefail

req() { test -f "$1" || { echo "ملف ناقص: $1 (طبّق المراحل السابقة أولاً)"; exit 1; }; }
req lib/ui/home_screen.dart
req lib/ui/widgets.dart
req lib/ui/branding.dart
grep -q "kCreditPhone" lib/ui/branding.dart || { echo "طبّق patch_credit_phone_v1.sh أولاً"; exit 1; }
if [ -f lib/ui/about_screen.dart ]; then echo "مطبّق سابقاً"; exit 0; fi

mkdir -p lib/ui test

# ───────────────────────── 1) معلومات التطبيق ─────────────────────────
cat > lib/ui/app_info.dart <<'DART_EOF'
/// معلومات التطبيق المعروضة في «حول البرنامج».
const String kAppName = 'شجرة عائلتي';
const String kAppVersion = '0.1.0';

/// رقم البناء من GitHub Actions (--dart-define=BUILD_NUMBER=...)؛ فارغ في التشغيل المحلي.
const String kBuildNumber = String.fromEnvironment('BUILD_NUMBER');
DART_EOF

# ───────────────────────── 2) شاشة حول البرنامج ─────────────────────────
cat > lib/ui/about_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_info.dart';
import 'branding.dart';
import 'widgets.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  bool _copied = false;

  Widget _para(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: Text(text, style: const TextStyle(height: 1.5)),
      ),
    );
  }

  Widget _feature(IconData icon, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }

  Widget _header() {
    final version = kBuildNumber.isEmpty
        ? 'الإصدار $kAppVersion'
        : 'الإصدار $kAppVersion • بناء $kBuildNumber';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Colors.blue.shade700, Colors.blue.shade400],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade700,
                child: const Icon(Icons.account_tree, size: 44),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              kAppName,
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'إدارة شجرة العائلة دون إنترنت',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                version,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final year = DateTime.now().year;
    return Scaffold(
      appBar: AppBar(title: const Text('حول البرنامج')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _header(),
          SectionCard(
            title: 'عن البرنامج',
            icon: Icons.info_outline,
            children: [
              _para(
                'برنامج شخصي لتوثيق أفراد العائلة وعلاقاتهم: الآباء والأمهات '
                'والأبناء والزواج، مع شجرة نسب وخريطة ذهنية وبطاقة لكل فرد. '
                'يعمل بالكامل على جهازك دون إنترنت ودون أي خادم.',
              ),
            ],
          ),
          SectionCard(
            title: 'المميزات',
            icon: Icons.star_outline,
            children: [
              _feature(Icons.groups, 'إدارة مئات الأفراد وأكثر بإضافة وتعديل وحذف.'),
              _feature(Icons.family_restroom,
                  'تسجيل الأب والأم والإخوة والأبناء وعلاقات الزواج المستقلة.'),
              _feature(Icons.account_tree,
                  'شجرة نسب تفاعلية: فتح الفروع وإغلاقها والبحث بالاسم.'),
              _feature(Icons.hub,
                  'خريطة ذهنية ملوّنة قابلة للتكبير وملء الشاشة وحفظها كصورة.'),
              _feature(Icons.image_outlined,
                  'بطاقة لكل فرد تُحفظ أو تُشارك كصورة بجودة FHD أو 4K.'),
              _feature(Icons.swap_vert, 'ترتيب الأبناء حسب العمر بأسهم التحريك.'),
              _feature(Icons.table_chart,
                  'استيراد من Excel وCSV مع معاينة وتحقق من البيانات.'),
              _feature(Icons.save_alt, 'نسخ احتياطي واستعادة لكل الأفراد والعلاقات.'),
              _feature(Icons.shield_outlined,
                  'منع حلقات النسب والأخطاء والتكرار عند الإدخال.'),
            ],
          ),
          SectionCard(
            title: 'الخصوصية والبيانات',
            icon: Icons.lock_outline,
            children: [
              _para(
                'بياناتك محفوظة على هذا الهاتف فقط ولا تُرسل إلى أي جهة. '
                'حذف التطبيق من الهاتف يمسح بياناته، فاحتفظ بنسخة احتياطية '
                'خارج الهاتف (من «الأفراد» ثم أيقونة النسخ الاحتياطي).',
              ),
            ],
          ),
          SectionCard(
            title: 'نصائح سريعة',
            icon: Icons.lightbulb_outline,
            children: [
              _feature(Icons.edit_outlined,
                  'اكتب الاسم الأول فقط، وتُضاف أسماء الآباء تلقائياً للتفريق بين المتشابهين.'),
              _feature(Icons.child_care,
                  'أضف الأبناء من صفحة الأب أو الأم لتُملأ بياناتهما تلقائياً.'),
              _feature(Icons.cloud_upload_outlined,
                  'صدّر نسخة احتياطية قبل تثبيت أي تحديث جديد.'),
              _feature(Icons.touch_app_outlined,
                  'في الخريطة: اضغط مطولاً على أي شخص لجعله جذر الخريطة.'),
            ],
          ),
          SectionCard(
            title: 'التصميم والتواصل',
            icon: Icons.brush_outlined,
            children: [
              _feature(Icons.person_outline, 'تصميم: $kCreditName'),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 20, color: scheme.primary),
                    const SizedBox(width: 10),
                    SelectableText(
                      kCreditPhone,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'نسخ الرقم',
                      icon: Icon(_copied ? Icons.check : Icons.copy, size: 20),
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: kCreditPhone),
                        );
                        if (mounted) setState(() => _copied = true);
                      },
                    ),
                  ],
                ),
              ),
              _para('للاستيراد أو إضافة أفراد أو أي استفسار تواصل معنا على الرقم أعلاه.'),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                '© $year جميع الحقوق محفوظة',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
DART_EOF

# ───────────────────────── 3) تبويب رابع «حول» ─────────────────────────
cat > lib/ui/home_screen.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../app_state.dart';
import 'about_screen.dart';
import 'mind_map_screen.dart';
import 'person_list_screen.dart';
import 'tree_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          PersonListScreen(state: widget.state),
          TreeScreen(state: widget.state),
          MindMapScreen(state: widget.state),
          const AboutScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.people), label: 'الأفراد'),
          NavigationDestination(icon: Icon(Icons.account_tree), label: 'الشجرة'),
          NavigationDestination(icon: Icon(Icons.hub), label: 'الخريطة'),
          NavigationDestination(icon: Icon(Icons.info_outline), label: 'حول'),
        ],
      ),
    );
  }
}
DART_EOF

# ───────────────────────── 4) رقم البناء من CI ─────────────────────────
wf=.github/workflows/build.yml
if [ -f "$wf" ] && grep -q -- "--build-number=" "$wf" && ! grep -q "BUILD_NUMBER" "$wf"; then
  sed -i 's|--build-number=${{ github.run_number }}|--build-number=${{ github.run_number }} --dart-define=BUILD_NUMBER=${{ github.run_number }}|' "$wf"
  grep -q "BUILD_NUMBER=" "$wf"
fi

# ───────────────────────── 5) اختبار بسيط للشاشة ─────────────────────────
cat > test/about_screen_test.dart <<'DART_EOF'
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
DART_EOF

echo "تمت إضافة صفحة حول البرنامج (تبويب رابع)."
