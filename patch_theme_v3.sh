#!/usr/bin/env bash
# شجرة عائلتي - السمة v3: ألوان بطاقة الفرد (Material Blue) على التطبيق كله (بديلة عن v1 وv2)
# شغّله من جذر المستودع: bash patch_theme_v3.sh
set -euo pipefail

test -f lib/main.dart || { echo "lib/main.dart غير موجود"; exit 1; }
d=lib/ui/person_detail_screen.dart
test -f "$d" || { echo "طبّق المراحل السابقة أولاً"; exit 1; }
test -f lib/ui/widgets.dart || { echo "lib/ui/widgets.dart غير موجود"; exit 1; }

# ───────────────────────── 1) السمة ─────────────────────────
# الدرجات من الصورة: Blue 700 #1976D2 ← 400 #42A5F5 (التدرج)، 50 #E3F2FD (الأشرطة)،
# 100 #BBDEFB (الحدود)، 800 #1565C0 (العناوين)، 900 #0D47A1.
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

ColorScheme _scheme(Brightness b) {
  final base = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1976D2),
    brightness: b,
  );
  if (b == Brightness.light) {
    return base.copyWith(
      primary: const Color(0xFF1976D2), // Blue 700
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFE3F2FD), // Blue 50
      onPrimaryContainer: const Color(0xFF0D47A1), // Blue 900
      secondary: const Color(0xFF1565C0), // Blue 800
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFBBDEFB), // Blue 100
      onSecondaryContainer: const Color(0xFF0D47A1),
      tertiary: const Color(0xFF2196F3), // Blue 500
      onTertiary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF14213D),
      onSurfaceVariant: const Color(0xFF475A7A),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: const Color(0xFFF3F9FF),
      surfaceContainer: const Color(0xFFE9F3FD),
      surfaceContainerHigh: const Color(0xFFDDECFB),
      surfaceContainerHighest: const Color(0xFFCFE3F8),
      outline: const Color(0xFF7FA7D4),
      outlineVariant: const Color(0xFFCFE3F8),
      surfaceTint: Colors.transparent,
    );
  }
  return base.copyWith(
    primary: const Color(0xFF64B5F6), // Blue 300
    onPrimary: const Color(0xFF0D2B52),
    primaryContainer: const Color(0xFF0D47A1),
    onPrimaryContainer: const Color(0xFFE3F2FD),
    secondary: const Color(0xFF90CAF9), // Blue 200
    onSecondary: const Color(0xFF0D2B52),
    secondaryContainer: const Color(0xFF1565C0),
    onSecondaryContainer: const Color(0xFFE3F2FD),
    tertiary: const Color(0xFF42A5F5),
    onTertiary: const Color(0xFF0D2B52),
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
  final cardColor = dark ? const Color(0xFF111B31) : const Color(0xFFF3F9FF);
  final fieldFill = dark ? const Color(0xFF16233F) : const Color(0xFFE9F3FD);
  final appBarColor = dark ? const Color(0xFF0D3C7A) : const Color(0xFF1976D2);
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
      backgroundColor: dark ? const Color(0xFF16233F) : Colors.white,
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
              ? (dark ? scheme.primary : scheme.secondary)
              : scheme.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected)
              ? (dark ? scheme.primary : scheme.secondary)
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
      backgroundColor: dark ? const Color(0xFF233659) : const Color(0xFF0D2B52),
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

# ───────────────────────── 2) عناصر الواجهة: عناوين الأقسام كما في الصورة ─────────────────────────
cat > lib/ui/widgets.dart <<'DART_EOF'
import 'package:flutter/material.dart';

import '../data/models/person.dart';
import 'ui_helpers.dart';

/// صورة رمزية حسب الجنس (بلا صور شخصية في هذه النسخة).
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({super.key, required this.gender, this.radius = 20});

  final Gender gender;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (gender) {
      Gender.male => (Colors.blue.shade100, Colors.blue.shade800),
      Gender.female => (Colors.pink.shade100, Colors.pink.shade800),
      Gender.unknown => (Colors.blueGrey.shade100, Colors.blueGrey.shade700),
    };
    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      foregroundColor: fg,
      child: Icon(genderIcon(gender), size: radius * 1.15),
    );
  }
}

/// بطاقة قسم: أيقونة في دائرة زرقاء فاتحة، عنوان أزرق غامق، وخط رفيع (كبطاقة الفرد).
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: scheme.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.secondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Divider(height: 1, color: scheme.outlineVariant),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: color),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
DART_EOF

# ───────────────────────── 3) ترويسة تفاصيل الشخص: تدرج أزرق وشريط إحصاءات كالبطاقة ─────────────────────────
if ! grep -q "Colors.blue.shade400" "$d"; then
  stat_new="$(mktemp)"
  head_new="$(mktemp)"

  cat > "$stat_new" <<'DART_EOF'
  Widget _stat(BuildContext context, String label, int value) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: scheme.onPrimaryContainer,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onPrimaryContainer.withAlpha(190),
            ),
          ),
        ],
      ),
    );
  }
DART_EOF

  cat > "$head_new" <<'DART_EOF'
  Widget _header(
    BuildContext context,
    Person p, {
    required int kids,
    required int spouses,
    required int sibs,
  }) {
    final parents = state.parentsLabel(p);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
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
                    radius: 38,
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade700,
                    child: Icon(genderIcon(p.gender), size: 44),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  state.displayName(p),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.25,
                  ),
                ),
                if (parents != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    parents,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    genderLabel(p.gender),
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
          Container(
            color: scheme.primaryContainer,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                _stat(context, 'الأبناء', kids),
                _stat(context, 'الزواج', spouses),
                _stat(context, 'الإخوة', sibs),
              ],
            ),
          ),
        ],
      ),
    );
  }
DART_EOF

  awk -v statf="$stat_new" -v headf="$head_new" '
    /^  Widget _stat\(BuildContext context, IconData icon, String label, int value\) \{$/ {
      while ((getline l < statf) > 0) print l
      skip = 1; next
    }
    /^  Widget _header\($/ {
      while ((getline l < headf) > 0) print l
      skip = 1; next
    }
    skip && /^  }$/ { skip = 0; next }
    !skip { print }
  ' "$d" > "$d.new"
  mv "$d.new" "$d"
  rm -f "$stat_new" "$head_new"
fi
grep -q "Colors.blue.shade400" "$d"
grep -q "_stat(context, 'الأبناء', kids)" "$d"
if grep -q "IconData icon, String label, int value" "$d"; then echo "تعذّر استبدال _stat"; exit 1; fi
test "$(grep -c 'Widget _header(' "$d")" = "1"

# ───────────────────────── 4) نصوص اللافتة في قائمة الأفراد أوضح ─────────────────────────
l=lib/ui/person_list_screen.dart
if [ -f "$l" ]; then
  sed -i 's/on\.withAlpha(200)/on/; s/on\.withAlpha(220)/on/' "$l"
fi

# ───────────────────────── 5) ألوان الخريطة وبطاقة الفرد وأيقونة التطبيق (بلا أخضر) ─────────────────────────
m=lib/ui/mind_map_screen.dart
if [ -f "$m" ]; then
  sed -i 's/0xFF00897B/0xFFC62828/; s/0xFF43A047/0xFF455A64/' "$m"
  if grep -q "0xFF00897B\|0xFF43A047" "$m"; then echo "تعذّر تعديل ألوان الخريطة"; exit 1; fi
fi
c=lib/ui/person_card.dart
if [ -f "$c" ]; then
  sed -i 's/^  Colors.green,$/  Colors.red,/; s/^  Colors.teal,$/  Colors.blueGrey,/; s/Gender.unknown => Colors.teal,/Gender.unknown => Colors.blueGrey,/' "$c"
  if grep -q "Colors.green\|Colors.teal" "$c"; then echo "تعذّر تعديل ألوان البطاقة"; exit 1; fi
fi
if [ -d tool/android_res/values ]; then
  cat > tool/android_res/values/colors.xml <<'XML_EOF'
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#1976D2</color>
</resources>
XML_EOF
fi

echo "تم تطبيق السمة v3 (ألوان بطاقة الفرد على التطبيق كله)."
