import 'package:material_ui/material_ui.dart';

class AppTheme {
  AppTheme._();

  static const _navy = Color(0xFF071326);
  static const _navySurface = Color(0xFF101F39);
  static const _gold = Color(0xFFD4A62A);
  static const _lightGold = Color(0xFF8A650E);
  static const _ivory = Color(0xFFF1E8D2);
  static const _lightBackground = Color(0xFFF5F6F8);
  static const _lightSurface = Color(0xFFFFFEFC);
  static const _lightSurfaceContainer = Color(0xFFF0F2F5);
  static const _darkSurfaceContainer = Color(0xFF172842);

  static final light = _buildTheme(_lightScheme, isDark: false);
  static final dark = _buildTheme(_darkScheme, isDark: true);

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: _navy,
    brightness: Brightness.light,
  ).copyWith(
    primary: const Color(0xFF263B5B),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFE6ECF4),
    onPrimaryContainer: const Color(0xFF172A45),
    secondary: _lightGold,
    onSecondary: Colors.white,
    secondaryContainer: const Color(0xFFF4E9CC),
    onSecondaryContainer: const Color(0xFF493507),
    tertiary: const Color(0xFF397565),
    onTertiary: Colors.white,
    surface: _lightSurface,
    onSurface: const Color(0xFF202938),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF9FAFB),
    surfaceContainer: _lightSurfaceContainer,
    surfaceContainerHigh: const Color(0xFFE9EDF2),
    surfaceContainerHighest: const Color(0xFFE2E7ED),
    outline: const Color(0xFF788392),
    outlineVariant: const Color(0xFFD5DBE3),
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: _gold,
    brightness: Brightness.dark,
  ).copyWith(
    primary: _gold,
    onPrimary: _navy,
    primaryContainer: const Color(0xFF3B321D),
    onPrimaryContainer: const Color(0xFFF5DEA0),
    secondary: const Color(0xFFD9C38D),
    onSecondary: _navy,
    secondaryContainer: const Color(0xFF343047),
    onSecondaryContainer: _ivory,
    tertiary: const Color(0xFF82C7B3),
    onTertiary: _navy,
    surface: _navySurface,
    onSurface: _ivory,
    surfaceContainerLowest: _navy,
    surfaceContainerLow: const Color(0xFF0D1A30),
    surfaceContainer: _navySurface,
    surfaceContainerHigh: _darkSurfaceContainer,
    surfaceContainerHighest: const Color(0xFF20344F),
    outline: const Color(0xFF8291A8),
    outlineVariant: const Color(0xFF344A66),
  );

  static ThemeData _buildTheme(
    ColorScheme scheme, {
    required bool isDark,
  }) {
    final radius = BorderRadius.circular(16);
    final smallRadius = BorderRadius.circular(12);
    final border = BorderSide(color: scheme.outlineVariant);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? _navy : _lightBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? _navy : _lightBackground,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: border,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: smallRadius,
          borderSide: border,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: smallRadius,
          borderSide: border,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: smallRadius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: smallRadius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: smallRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: smallRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: smallRadius),
          side: border,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: smallRadius),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: scheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: smallRadius),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: isDark ? _navySurface : _lightSurface,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? _navySurface : _lightSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: border,
        ),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? _navySurface : _lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minVerticalPadding: 8,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF263B5B) : const Color(0xFF263B5B),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: smallRadius),
      ),
    );
  }
}
