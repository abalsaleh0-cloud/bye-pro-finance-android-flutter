import 'package:expense_app/core/theme/app_appearance.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:material_ui/material_ui.dart';

class AppTheme {
  AppTheme._();

  static const _navy = Color(0xFF071326);
  static const _navySurface = Color(0xFF101F39);
  static const _gold = Color(0xFFD4A62A);
  static const _ivory = Color(0xFFF1E8D2);
  static const _lightBackground = Color(0xFFF5F6F8);
  static const _lightSurface = Color(0xFFFFFEFC);
  static const _lightSurfaceContainer = Color(0xFFF0F2F5);
  static const _darkSurfaceContainer = Color(0xFF172842);

  /// Backward-compatible defaults for callers that use the original fields.
  static ThemeData get light => lightFor();
  static ThemeData get dark => darkFor();

  static ThemeData lightFor({
    AppThemePreset preset = AppThemePreset.navyGold,
    AppDensity density = AppDensity.comfortable,
  }) {
    return _buildTheme(
      _colorScheme(preset: preset, isDark: false),
      isDark: false,
      density: density,
    );
  }

  static ThemeData darkFor({
    AppThemePreset preset = AppThemePreset.navyGold,
    AppDensity density = AppDensity.comfortable,
  }) {
    return _buildTheme(
      _colorScheme(preset: preset, isDark: true),
      isDark: true,
      density: density,
    );
  }

  static ColorScheme _colorScheme({
    required AppThemePreset preset,
    required bool isDark,
  }) {
    switch (preset) {
      case AppThemePreset.navyGold:
        return _navyGoldScheme(isDark: isDark);
      case AppThemePreset.emerald:
        return _emeraldScheme(isDark: isDark);
      case AppThemePreset.graphite:
        return _graphiteScheme(isDark: isDark);
    }
  }

  static ColorScheme _navyGoldScheme({required bool isDark}) {
    if (!isDark) {
      return ColorScheme.fromSeed(
        seedColor: _navy,
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF263B5B),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFE6ECF4),
        onPrimaryContainer: const Color(0xFF172A45),
        secondary: const Color(0xFF8A650E),
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
    }

    return ColorScheme.fromSeed(
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
  }

  static ColorScheme _emeraldScheme({required bool isDark}) {
    if (!isDark) {
      return ColorScheme.fromSeed(
        seedColor: const Color(0xFF176B5B),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF176B5B),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFD7EEE7),
        onPrimaryContainer: const Color(0xFF123F35),
        secondary: const Color(0xFF8C6D2D),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFF3E8C9),
        onSecondaryContainer: const Color(0xFF49370D),
        tertiary: const Color(0xFF526A9A),
        onTertiary: Colors.white,
        surface: const Color(0xFFFFFEFA),
        onSurface: const Color(0xFF202B29),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF8FAF8),
        surfaceContainer: const Color(0xFFEFF4F1),
        surfaceContainerHigh: const Color(0xFFE5ECE8),
        surfaceContainerHighest: const Color(0xFFDCE6E1),
        outline: const Color(0xFF74857E),
        outlineVariant: const Color(0xFFD1DDD6),
      );
    }

    return ColorScheme.fromSeed(
      seedColor: const Color(0xFF79D4BC),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFF79D4BC),
      onPrimary: const Color(0xFF06251F),
      primaryContainer: const Color(0xFF1C443A),
      onPrimaryContainer: const Color(0xFFC7F1E4),
      secondary: const Color(0xFFE2C982),
      onSecondary: const Color(0xFF2F260F),
      secondaryContainer: const Color(0xFF453A20),
      onSecondaryContainer: const Color(0xFFF6E8BA),
      tertiary: const Color(0xFFA9BCEB),
      onTertiary: const Color(0xFF1A2945),
      surface: const Color(0xFF10211D),
      onSurface: const Color(0xFFE1EEE8),
      surfaceContainerLowest: const Color(0xFF0A1714),
      surfaceContainerLow: const Color(0xFF0D1D19),
      surfaceContainer: const Color(0xFF10211D),
      surfaceContainerHigh: const Color(0xFF1A302A),
      surfaceContainerHighest: const Color(0xFF254139),
      outline: const Color(0xFF8EA99D),
      outlineVariant: const Color(0xFF38564A),
    );
  }

  static ColorScheme _graphiteScheme({required bool isDark}) {
    if (!isDark) {
      return ColorScheme.fromSeed(
        seedColor: const Color(0xFF43536C),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF43536C),
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFE0E7F0),
        onPrimaryContainer: const Color(0xFF202D41),
        secondary: const Color(0xFF876B3D),
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFF1E8D8),
        onSecondaryContainer: const Color(0xFF493718),
        tertiary: const Color(0xFF466E76),
        onTertiary: Colors.white,
        surface: const Color(0xFFFCFCFD),
        onSurface: const Color(0xFF242A33),
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFF7F8FA),
        surfaceContainer: const Color(0xFFEEF0F3),
        surfaceContainerHigh: const Color(0xFFE5E8ED),
        surfaceContainerHighest: const Color(0xFFDCE1E8),
        outline: const Color(0xFF737C89),
        outlineVariant: const Color(0xFFD2D7DF),
      );
    }

    return ColorScheme.fromSeed(
      seedColor: const Color(0xFFB0C7EC),
      brightness: Brightness.dark,
    ).copyWith(
      primary: const Color(0xFFB0C7EC),
      onPrimary: const Color(0xFF172234),
      primaryContainer: const Color(0xFF30425D),
      onPrimaryContainer: const Color(0xFFDCE8FA),
      secondary: const Color(0xFFE2C78A),
      onSecondary: const Color(0xFF322610),
      secondaryContainer: const Color(0xFF4B3B20),
      onSecondaryContainer: const Color(0xFFF4E6C1),
      tertiary: const Color(0xFF9ACBC4),
      onTertiary: const Color(0xFF163431),
      surface: const Color(0xFF171B23),
      onSurface: const Color(0xFFE7EAF0),
      surfaceContainerLowest: const Color(0xFF11151C),
      surfaceContainerLow: const Color(0xFF141922),
      surfaceContainer: const Color(0xFF171B23),
      surfaceContainerHigh: const Color(0xFF202733),
      surfaceContainerHighest: const Color(0xFF2A3341),
      outline: const Color(0xFF99A4B5),
      outlineVariant: const Color(0xFF414C5D),
    );
  }

  static ThemeData _buildTheme(
    ColorScheme scheme, {
    required bool isDark,
    required AppDensity density,
  }) {
    final tokens = AppDesignTokens.forDensity(density);
    final radius = BorderRadius.circular(tokens.cardRadius);
    final smallRadius = BorderRadius.circular(tokens.controlRadius);
    final border = BorderSide(color: scheme.outlineVariant);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [tokens],
      scaffoldBackgroundColor: isDark
          ? scheme.surfaceContainerLowest
          : scheme.surfaceContainer,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark
            ? scheme.surfaceContainerLowest
            : scheme.surfaceContainer,
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
        elevation: tokens.cardElevation,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: border,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: tokens.inputVerticalPadding,
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
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.dialogRadius),
          side: border,
        ),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.dialogRadius),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16).copyWith(
          vertical: tokens.listTileVerticalPadding,
        ),
        minVerticalPadding: tokens.listTileVerticalPadding,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: smallRadius),
      ),
    );
  }
}
