/// توحيد النص العربي للبحث: إزالة التشكيل والتطويل، وتوحيد الهمزات والتاء المربوطة والألف المقصورة.
String normalizeArabic(String input) {
  var s = input.toLowerCase();
  s = s.replaceAll(RegExp('[\u064B-\u065F\u0670\u0640]'), '');
  s = s.replaceAll(RegExp('[\u0623\u0625\u0622\u0671]'), '\u0627');
  s = s.replaceAll('\u0629', '\u0647');
  s = s.replaceAll('\u0649', '\u064A');
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  return s.trim();
}
