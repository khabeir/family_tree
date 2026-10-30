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

/// شريط رفيع بسطر واحد أسفل الخريطة المصدَّرة:
/// الحقوق عند أقصى اليمين (بداية السطر في العربية) والتاريخ عند أقصى اليسار.
Widget buildCreditBar({double height = 32, DateTime? now}) {
  return Container(
    height: height,
    color: Colors.blue.shade700,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Row(
      children: [
        const Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              kCreditText,
              style: TextStyle(
                inherit: false,
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          exportDateText(now),
          style: const TextStyle(
            inherit: false,
            color: Colors.white,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}
