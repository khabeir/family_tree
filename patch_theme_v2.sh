#!/usr/bin/env bash
# شجرة عائلتي - السمة v2 (بديلة عن patch_theme_v1.sh): خلفية بيضاء + تدرجات الأزرق
# شغّله من جذر المستودع: bash patch_theme_v2.sh   (يصلح سواء طبّقت v1 أم لا)
set -euo pipefail

test -f lib/main.dart || { echo "lib/main.dart غير موجود"; exit 1; }
test -f lib/ui/home_screen.dart || { echo "طبّق المراحل السابقة أولاً"; exit 1; }

# ───────────────────────── 1) السمة ─────────────────────────
cat > lib/main.dart <<'DART_EOF'
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'data/database/app_database.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  final state = AppState(db);
  await state.load();
  runApp(FamilyTreeApp(state: state));
}

/// لوحة الألوان:
///  - الخلفية: أبيض صريح.
///  - الأزرق بتدرجاته: كحلي #1E3A8A (ترويسات) ← أزرق #1E40AF (أساسي) ← #2563EB (تدرج)
///    ← أزرق فاتح #DBEAFE / #EEF4FF / #F5F9FF (بطاقات وحقول).
///  - نص: كحلي غامق #0B1B3A، والثانوي #475A7A.
///  - أحمر فقط للحذف/القلب، وكهرماني #F59E0B لإبراز نتيجة البحث. لا أخضر.
ColorScheme _scheme(Brightness b) {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1E40AF),
    brightness: b,
  );
  if (b == Brightness.light) {
    return base.copyWith(
      primary: const Color(0xFF1E40AF),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDBEAFE),
      onPrimaryContainer: const Color(0xFF1E3A8A),
      secondary: const Color(0xFF0369A1),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE0F2FE),
      onSecondaryContainer: const Color(0xFF0C4A6E),
      tertiary: const Color(0xFF2563EB),
      onTertiary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF0B1B3A),
      onSurfaceVariant: const Color(0xFF475A7A),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF5F9FF),
      surfaceContainer: const Color(0xFFEEF4FF),
      surfaceContainerHigh: const Color(0xFFE3EDFE),
      surfaceContainerHighest: const Color(0xFFD9E6FD),
      outline: const Color(0xFF8CA3C7),
      outlineVariant: const Color(0xFFD3E1FA),
      surfaceTint: Colors.transparent,
    );
  }
  return base.copyWith(
    primary: const Color(0xFF93C5FD),
    onPrimary: const Color(0xFF0B2A5B),
    primaryContainer: const Color(0xFF1E3A8A),
    onPrimaryContainer: const Color(0xFFDBEAFE),
    secondary: const Color(0xFF7DD3FC),
    onSecondary: const Color(0xFF0C4A6E),
    secondaryContainer: const Color(0xFF0C4A6E),
    onSecondaryContainer: const Color(0xFFE0F2FE),
    tertiary: const Color(0xFF60A5FA),
    onTertiary: const Color(0xFF0B2A5B),
    surface: const Color(0xFF0B1220),
    onSurface: const Color(0xFFEFF6FF),
    onSurfaceVariant: const Color(0xFFBFD3F2),
    surfaceContainerLowest: const Color(0xFF080E1A),
    surfaceContainerLow: const Color(0xFF111B31),
    surfaceContainer: const Color(0xFF16233F),
    surfaceContainerHigh: const Color(0xFF1C2C4E),
    surfaceContainerHighest: const Color(0xFF233659),
    outline: const Color(0xFF5B729A),
    outlineVariant: const Color(0xFF263B63),
    surfaceTint: Colors.transparent,
  );
}

ThemeData _buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = _scheme(b);
  final scaffold = dark ? const Color(0xFF0B1220) : Colors.white;
  final cardColor = dark ? const Color(0xFF111B31) : const Color(0xFFF5F9FF);
  final fieldFill = dark ? const Color(0xFF16233F) : const Color(0xFFEEF4FF);
  final appBarColor = dark ? const Color(0xFF172554) : const Color(0xFF1E40AF);
  final shape12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 2,
      backgroundColor: appBarColor,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    ),
    cardTheme: CardTheme(
      color: cardColor,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: fieldFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    listTileTheme: ListTileThemeData(shape: shape12),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.primary,
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: scaffold,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: dark ? const Color(0xFF111B31) : Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: dark ? const Color(0xFF111B31) : Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xFF111B31) : Colors.white,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF233659) : const Color(0xFF0F1F4D),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: shape12,
    ),
  );
}

class FamilyTreeApp extends StatelessWidget {
  const FamilyTreeApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'شجرة عائلتي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: HomeScreen(state: state),
    );
  }
}
DART_EOF

# ───────────────────────── 2) ألوان الخريطة الذهنية (بلا أخضر) ─────────────────────────
m=lib/ui/mind_map_screen.dart
if [ -f "$m" ]; then
  sed -i 's/0xFF00897B/0xFFC62828/; s/0xFF43A047/0xFF455A64/' "$m"
  if grep -q "0xFF00897B\|0xFF43A047" "$m"; then echo "تعذّر تعديل ألوان الخريطة"; exit 1; fi
fi

# ───────────────────────── 3) ألوان بطاقة الفرد (بلا أخضر/تركواز) ─────────────────────────
c=lib/ui/person_card.dart
if [ -f "$c" ]; then
  sed -i 's/^  Colors.green,$/  Colors.red,/; s/^  Colors.teal,$/  Colors.blueGrey,/; s/Gender.unknown => Colors.teal,/Gender.unknown => Colors.blueGrey,/' "$c"
  if grep -q "Colors.green\|Colors.teal" "$c"; then echo "تعذّر تعديل ألوان البطاقة"; exit 1; fi
fi

# ───────────────────────── 4) خلفية أيقونة التطبيق ─────────────────────────
if [ -d tool/android_res/values ]; then
  cat > tool/android_res/values/colors.xml <<'XML_EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#1E40AF</color>
</resources>
XML_EOF
fi

echo "تم تطبيق السمة v2 (خلفية بيضاء + تدرجات الأزرق)."
