#!/usr/bin/env bash
# شجرة عائلتي - القفل v2 (بديل عن patch_lock_v1.sh؛ يصلح سواء طبّقت v1 أم لا):
#  - كود يومي = اليوم × 999 × الشهر (مثال: 30/10 ← 299700)
#  - يحمي: الاستيراد، النسخ الاحتياطي والتصدير، وإضافة أفراد جدد
#  - يعرض تنبيه التواصل مع الرقم داخل نافذة الكود
# شغّله من جذر المستودع: bash patch_lock_v2.sh
set -euo pipefail

l=lib/ui/person_list_screen.dart
f=lib/ui/person_form_screen.dart
test -f "$l" || { echo "ملف قائمة الأفراد غير موجود"; exit 1; }
test -f "$f" || { echo "ملف نموذج الشخص غير موجود"; exit 1; }
grep -q "ImportScreen(state: state)" "$l" || { echo "لم يُعثر على زر الاستيراد (طبّق المراحل السابقة)"; exit 1; }
grep -q "BackupScreen(state: state)" "$l" || { echo "لم يُعثر على زر النسخ الاحتياطي (طبّق المراحل السابقة)"; exit 1; }

mkdir -p lib/domain lib/ui test

# ───────────────────────── 1) حساب الكود والتحقق منه (Dart صرف) ─────────────────────────
cat > lib/domain/access_code.dart <<'DART_EOF'
/// كود الفتح اليومي: اليوم × 999 × الشهر (بتوقيت الجهاز).
/// مثال: 30 أكتوبر ← 30 × 999 × 10 = 299700.
int unlockCodeFor(DateTime date) => date.day * 999 * date.month;

const Map<String, String> _digitMap = {
  '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
  '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
  '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
  '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
};

/// يحوّل الأرقام العربية/الفارسية إلى لاتينية.
String normalizeDigits(String input) {
  final buf = StringBuffer();
  for (final rune in input.runes) {
    final c = String.fromCharCode(rune);
    buf.write(_digitMap[c] ?? c);
  }
  return buf.toString();
}

/// هل [input] هو كود [date]؟ يقبل الأرقام العربية والمسافات وفواصل الآلاف.
bool isValidUnlockCode(String input, DateTime date) {
  final cleaned = normalizeDigits(input).replaceAll(RegExp(r'[\s,،٬]'), '');
  final value = int.tryParse(cleaned);
  return value != null && value == unlockCodeFor(date);
}
DART_EOF

# ───────────────────────── 2) تنبيه التواصل ─────────────────────────
cat > lib/ui/contact.dart <<'DART_EOF'
/// رقم التواصل ونص التنبيه الذي يظهر عند طلب كود الفتح.
const String kContactPhone = '0914111214';
const String kContactNotice =
    'تنبيه: إذا أردت استخدام التطبيق باستيراد أو إضافة أفراد تواصل معنا';
DART_EOF

# ───────────────────────── 3) بوابة الدخول ─────────────────────────
cat > lib/ui/access_gate.dart <<'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/access_code.dart';
import 'contact.dart';

/// حالة الفتح داخل الذاكرة: تبقى مفتوحة [sessionLength] بعد إدخال الكود الصحيح،
/// وبعد [maxFailures] محاولات خاطئة يُمنع الإدخال [blockLength].
class AccessGate {
  AccessGate._();

  static const Duration sessionLength = Duration(minutes: 10);
  static const Duration blockLength = Duration(minutes: 1);
  static const int maxFailures = 5;

  static DateTime? _unlockedUntil;
  static DateTime? _blockedUntil;
  static int _failures = 0;

  static bool get isUnlocked {
    final until = _unlockedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  static void lockNow() => _unlockedUntil = null;

  static void _unlock(DateTime now) {
    _unlockedUntil = now.add(sessionLength);
    _failures = 0;
    _blockedUntil = null;
  }

  /// يسجّل محاولة خاطئة؛ يعيد true إن صار الإدخال ممنوعاً.
  static bool _registerFailure(DateTime now) {
    _failures++;
    if (_failures >= maxFailures) {
      _failures = 0;
      _blockedUntil = now.add(blockLength);
      return true;
    }
    return false;
  }

  /// true إن كانت الشاشة مفتوحة أو أدخل المستخدم الكود الصحيح.
  static Future<bool> ensureUnlocked(BuildContext context) async {
    if (isUnlocked) return true;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _CodeDialog(),
    );
    return ok ?? false;
  }
}

class _ContactNotice extends StatefulWidget {
  const _ContactNotice();

  @override
  State<_ContactNotice> createState() => _ContactNoticeState();
}

class _ContactNoticeState extends State<_ContactNotice> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = scheme.onPrimaryContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kContactNotice,
                  style: TextStyle(color: fg, height: 1.4),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.phone, size: 18, color: fg),
                    const SizedBox(width: 6),
                    SelectableText(
                      kContactPhone,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: fg,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'نسخ الرقم',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        _copied ? Icons.check : Icons.copy,
                        size: 18,
                        color: fg,
                      ),
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: kContactPhone),
                        );
                        if (mounted) setState(() => _copied = true);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeDialog extends StatefulWidget {
  const _CodeDialog();

  @override
  State<_CodeDialog> createState() => _CodeDialogState();
}

class _CodeDialogState extends State<_CodeDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final now = DateTime.now();
    final blocked = AccessGate._blockedUntil;
    if (blocked != null && now.isBefore(blocked)) {
      final secs = blocked.difference(now).inSeconds + 1;
      setState(() => _error = 'محاولات كثيرة. انتظر $secs ثانية');
      return;
    }
    if (isValidUnlockCode(_controller.text, now)) {
      AccessGate._unlock(now);
      Navigator.of(context).pop(true);
      return;
    }
    final blockedNow = AccessGate._registerFailure(now);
    setState(() {
      _error = blockedNow ? 'محاولات كثيرة. انتظر دقيقة' : 'الكود غير صحيح';
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lock_outline),
          SizedBox(width: 8),
          Text('شاشة محمية'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('أدخل الكود للمتابعة.'),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'الكود',
                errorText: _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            const _ContactNotice(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _submit, child: const Text('فتح')),
      ],
    );
  }
}

/// يغلّف شاشة محمية: يطلب الكود عند فتحها، وإن أُلغي الإدخال يعود للخلف.
class Gated extends StatefulWidget {
  const Gated({super.key, required this.child});

  final Widget child;

  @override
  State<Gated> createState() => _GatedState();
}

class _GatedState extends State<Gated> {
  late bool _ok = AccessGate.isUnlocked;

  @override
  void initState() {
    super.initState();
    if (!_ok) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  Future<void> _check() async {
    final ok = await AccessGate.ensureUnlocked(context);
    if (!mounted) return;
    if (ok) {
      setState(() => _ok = true);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ok) return widget.child;
    return Scaffold(
      appBar: AppBar(title: const Text('شاشة محمية')),
      body: const Center(child: Icon(Icons.lock_outline, size: 64)),
    );
  }
}
DART_EOF

# ───────────────────────── 4) تغليف الاستيراد والنسخ الاحتياطي ─────────────────────────
if ! grep -q "Gated(child: ImportScreen" "$l"; then
  sed -i "s|builder: (_) => ImportScreen(state: state)|builder: (_) => Gated(child: ImportScreen(state: state))|" "$l"
fi
if ! grep -q "Gated(child: BackupScreen" "$l"; then
  sed -i "s|builder: (_) => BackupScreen(state: state)|builder: (_) => Gated(child: BackupScreen(state: state))|" "$l"
fi
if ! grep -q "import 'access_gate.dart';" "$l"; then
  sed -i "s|import 'backup_screen.dart';|import 'access_gate.dart';\nimport 'backup_screen.dart';|" "$l"
fi
grep -q "Gated(child: ImportScreen(state: state))" "$l"
grep -q "Gated(child: BackupScreen(state: state))" "$l"
grep -q "import 'access_gate.dart';" "$l"

# ───────────────────────── 5) حماية إضافة أفراد جدد (كل المسارات) ─────────────────────────
# نموذج الشخص: عند الإضافة (person == null) يُغلَّف بالبوابة؛ التعديل بلا قفل.
if ! grep -q "Gated(child: form)" "$f"; then
  sed -i '/^  @override$/{N;s/^  @override\n  Widget build(BuildContext context) {$/  Widget _buildForm(BuildContext context) {/}' "$f"
  grep -q "Widget _buildForm(BuildContext context) {" "$f" || { echo "تعذّر إيجاد build في نموذج الشخص"; exit 1; }
  sed -i '/^  Widget _buildForm(BuildContext context) {$/i\  @override\n  Widget build(BuildContext context) {\n    final form = _buildForm(context);\n    return widget.person == null ? Gated(child: form) : form;\n  }\n' "$f"
  sed -i "s|import 'person_picker_screen.dart';|import 'access_gate.dart';\nimport 'person_picker_screen.dart';|" "$f"
fi
grep -q "Gated(child: form)" "$f"
grep -q "import 'access_gate.dart';" "$f"
test "$(grep -c 'Widget build(BuildContext context)' "$f")" = "1"
test "$(grep -c '_buildForm(context)' "$f")" = "1"
if grep -B1 "Widget _buildForm" "$f" | grep -q "@override"; then
  echo "بقي @override فوق _buildForm"; exit 1
fi

# ───────────────────────── 6) اختبارات الكود ─────────────────────────
cat > test/access_code_test.dart <<'DART_EOF'
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
DART_EOF

echo "تم تطبيق القفل v2: الاستيراد والنسخ الاحتياطي وإضافة الأفراد بكود يومي مع تنبيه التواصل."
