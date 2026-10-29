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
