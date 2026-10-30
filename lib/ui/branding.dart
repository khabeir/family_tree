import 'package:flutter/material.dart';

const String kCreditName = 'محمد برير حبيب الله';
const String kCreditPhone = '0914111214';

/// نص حقوق التصميم الذي يظهر أسفل الصور المصدَّرة.
const String kCreditText = '© تصميم : $kCreditName  •  $kCreditPhone';

/// شريط الحقوق السفلي للخريطة المصدَّرة (أزرق بنص أبيض، ويتقلّص النص إن ضاق العرض).
Widget buildCreditBar({double height = 40}) {
  return Container(
    height: height,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    color: Colors.blue.shade700,
    child: const FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        kCreditText,
        textAlign: TextAlign.center,
        style: TextStyle(
          inherit: false,
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
