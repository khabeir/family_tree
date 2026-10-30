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
