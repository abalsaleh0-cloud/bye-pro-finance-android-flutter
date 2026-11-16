import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// One fixed BYE PRO design system with two coordinated appearances.
/// Colour changes never alter component geometry or interaction behaviour.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _buildTheme(isDark: false);
  static ThemeData get dark => _buildTheme(isDark: true);

  static ColorScheme colorSchemeFor({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final seed = isDark
        ? const Color(0xFF8BB8F4)
        : const Color(0xFF245FAE);
    final generated = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    );

    return generated.copyWith(
      primary: isDark ? const Color(0xFF8BB8F4) : const Color(0xFF245FAE),
      onPrimary: isDark ? const Color(0xFF10233D) : Colors.white,
      primaryContainer:
          isDark ? const Color(0xFF203F66) : const Color(0xFFDCE9F8),
      onPrimaryContainer:
          isDark ? const Color(0xFFE1EEFF) : const Color(0xFF17385F),
      secondary: isDark ? const Color(0xFFE0BD69) : const Color(0xFF98701F),
      onSecondary: isDark ? const Color(0xFF2B210C) : Colors.white,
      secondaryContainer:
          isDark ? const Color(0xFF493919) : const Color(0xFFF3E8CB),
      onSecondaryContainer:
          isDark ? const Color(0xFFFFE8AE) : const Color(0xFF4D3910),
      surface: isDark ? const Color(0xFF101720) : const Color(0xFFF6F8FB),
      onSurface: isDark ? const Color(0xFFF1F4F8) : const Color(0xFF1B2735),
      onSurfaceVariant:
          isDark ? const Color(0xFFB6C1CF) : const Color(0xFF566476),
      surfaceDim: isDark ? const Color(0xFF0B1118) : const Color(0xFFE9EEF4),
      surfaceBright:
          isDark ? const Color(0xFF26313E) : const Color(0xFFFFFFFF),
      surfaceContainerLowest:
          isDark ? const Color(0xFF0D131B) : const Color(0xFFFFFFFF),
      surfaceContainerLow:
          isDark ? const Color(0xFF151E29) : const Color(0xFFFFFFFF),
      surfaceContainer:
          isDark ? const Color(0xFF1A2430) : const Color(0xFFF0F3F7),
      surfaceContainerHigh:
          isDark ? const Color(0xFF222E3B) : const Color(0xFFE8EDF3),
      surfaceContainerHighest:
          isDark ? const Color(0xFF2A3745) : const Color(0xFFDDE4EC),
      outline: isDark ? const Color(0xFF627184) : const Color(0xFF7D8997),
      outlineVariant:
          isDark ? const Color(0xFF354353) : const Color(0xFFD8DFE7),
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: isDark
          ? const Color(0xFF8BB8F4)
          : const Color(0xFF245FAE),
    );
  }

  static ThemeData _buildTheme({required bool isDark}) {
    final scheme = colorSchemeFor(
      brightness: isDark ? Brightness.dark : Brightness.light,
    );
    final tokens = AppDesignTokens.standard();
    final radius = BorderRadius.circular(tokens.cardRadius);
    final controlRadius = BorderRadius.circular(tokens.controlRadius);
    final dialogRadius = BorderRadius.circular(tokens.dialogRadius);
    final border = BorderSide(color: scheme.outlineVariant);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [tokens],
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surfaceContainerLow,
      textTheme: Typography.material2021(
        platform: TargetPlatform.android,
        colorScheme: scheme,
      ).black.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
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
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
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
          borderRadius: controlRadius,
          borderSide: border,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: border,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(48, tokens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(48, tokens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          side: border,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(tokens.touchTargetSize, tokens.touchTargetSize),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: Size(tokens.touchTargetSize, tokens.touchTargetSize),
          tapTargetSize: MaterialTapTargetSize.padded,
          foregroundColor: scheme.onSurfaceVariant,
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: const CircleBorder(),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: tokens.navigationBarHeight,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: controlRadius),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: dialogRadius,
          side: border,
        ),
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: dialogRadius,
          side: border,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: dialogRadius,
          side: border,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: dialogRadius,
          side: border,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        minVerticalPadding: 2,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: controlRadius),
      ),
    );
  }

  static double contrastRatio(Color foreground, Color background) {
    final first = foreground.computeLuminance();
    final second = background.computeLuminance();
    final lighter = first > second ? first : second;
    final darker = first > second ? second : first;
    return (lighter + .05) / (darker + .05);
  }
}
