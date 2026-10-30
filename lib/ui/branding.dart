import 'package:flutter/material.dart';

/// نص حقوق التصميم الذي يظهر أسفل الصور المصدَّرة.
const String kCreditText = '© تصميم : محمد برير حبيب الله';

/// شريط الحقوق السفلي للخريطة المصدَّرة (أزرق بنص أبيض).
Widget buildCreditBar({double height = 40}) {
  return Container(
    height: height,
    alignment: Alignment.center,
    color: Colors.blue.shade700,
    child: const Text(
      kCreditText,
      textAlign: TextAlign.center,
      style: TextStyle(
        inherit: false,
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}
