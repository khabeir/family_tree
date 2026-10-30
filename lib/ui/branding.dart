import 'package:flutter/material.dart';

const String kCreditName = 'محمد برير حبيب الله';
const String kCreditPhone = '0914111214';

/// نص حقوق التصميم الذي يظهر أسفل الصور المصدَّرة.
const String kCreditText = '© تصميم : $kCreditName  •  $kCreditPhone';

/// تاريخ التصدير بصيغة yyyy-MM-dd (تاريخ جهازك وقت الحفظ أو المشاركة).
String exportDateText([DateTime? now]) {
  final n = now ?? DateTime.now();
  String t(int v) => v.toString().padLeft(2, '0');
  return 'تاريخ التصدير: ${n.year}-${t(n.month)}-${t(n.day)}';
}

/// شريط الحقوق السفلي للخريطة المصدَّرة: سطر الحقوق ثم تاريخ التصدير
/// (أزرق بنص أبيض، ويتقلّص النص إن ضاق العرض).
Widget buildCreditBar({double height = 58, DateTime? now}) {
  return Container(
    height: height,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    color: Colors.blue.shade700,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            kCreditText,
            textAlign: TextAlign.center,
            style: TextStyle(
              inherit: false,
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            exportDateText(now),
            textAlign: TextAlign.center,
            style: const TextStyle(
              inherit: false,
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}
