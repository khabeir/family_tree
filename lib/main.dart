import 'package:flutter/material.dart';
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

const Color _brand = Color(0xFF1E40AF);

/// لوحة ألوان صريحة: أزرق للتمييز، رمادي-أزرق فاتح للخلفية، بطاقات بيضاء بحدود واضحة،
/// ونص داكن عالي التباين. لا ظلال ملوّنة (surfaceTint) ولا أخضر.
ColorScheme _scheme(Brightness b) {
  final base = ColorScheme.fromSeed(seedColor: _brand, brightness: b);
  if (b == Brightness.light) {
    return base.copyWith(
      primary: const Color(0xFF1E40AF),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFDBEAFE),
      onPrimaryContainer: const Color(0xFF1E3A8A),
      secondary: const Color(0xFF475569),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFE2E8F0),
      onSecondaryContainer: const Color(0xFF0F172A),
      tertiary: const Color(0xFF2563EB),
      onTertiary: Colors.white,
      surface: Colors.white,
      onSurface: const Color(0xFF0F172A),
      onSurfaceVariant: const Color(0xFF475569),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: const Color(0xFFF1F5F9),
      surfaceContainerHigh: const Color(0xFFE9EEF5),
      surfaceContainerHighest: const Color(0xFFE2E8F0),
      outline: const Color(0xFF94A3B8),
      outlineVariant: const Color(0xFFD9E0EA),
      surfaceTint: Colors.transparent,
    );
  }
  return base.copyWith(
    primary: const Color(0xFF93C5FD),
    onPrimary: const Color(0xFF0B2A5B),
    primaryContainer: const Color(0xFF1E3A8A),
    onPrimaryContainer: const Color(0xFFDBEAFE),
    secondary: const Color(0xFFCBD5E1),
    onSecondary: const Color(0xFF0F172A),
    secondaryContainer: const Color(0xFF334155),
    onSecondaryContainer: const Color(0xFFE2E8F0),
    tertiary: const Color(0xFF60A5FA),
    onTertiary: const Color(0xFF0B2A5B),
    surface: const Color(0xFF111827),
    onSurface: const Color(0xFFF1F5F9),
    onSurfaceVariant: const Color(0xFFCBD5E1),
    surfaceContainerLowest: const Color(0xFF0B1220),
    surfaceContainerLow: const Color(0xFF182235),
    surfaceContainer: const Color(0xFF1E293B),
    surfaceContainerHigh: const Color(0xFF243349),
    surfaceContainerHighest: const Color(0xFF2B3A52),
    outline: const Color(0xFF64748B),
    outlineVariant: const Color(0xFF334155),
    surfaceTint: Colors.transparent,
  );
}

ThemeData _buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = _scheme(b);
  final scaffold = dark ? const Color(0xFF0B1220) : const Color(0xFFF4F6FA);
  final cardColor = dark ? const Color(0xFF182235) : Colors.white;
  final fieldFill = dark ? const Color(0xFF1E293B) : Colors.white;
  final radius12 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 1,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
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
    listTileTheme: ListTileThemeData(shape: radius12),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    chipTheme: ChipThemeData(
      backgroundColor: cardColor,
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
      backgroundColor: scheme.surface,
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
      backgroundColor: cardColor,
      surfaceTintColor: Colors.transparent,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cardColor,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cardColor,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF334155) : const Color(0xFF1E293B),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: radius12,
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
