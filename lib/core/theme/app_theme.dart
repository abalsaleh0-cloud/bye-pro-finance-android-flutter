import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Telegram Android Blue (light) and Dark Blue (dark) color system.
///
/// Values are aligned with Telegram Android's official ThemeColors defaults
/// and its Dark Blue theme asset. Geometry remains controlled independently
/// by AppDesignTokens.
class AppTheme {
  AppTheme._();

  static const telegramBlue = Color(0xFF229AF0);
  static const telegramDarkBlue = Color(0xFF64B5EF);

  static ThemeData get light => _buildTheme(isDark: false);
  static ThemeData get dark => _buildTheme(isDark: true);

  static ColorScheme colorSchemeFor({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    if (isDark) {
      return const ColorScheme(
        brightness: Brightness.dark,
        primary: Color(0xFF64B5EF),
        onPrimary: Color(0xFF102A3D),
        primaryContainer: Color(0xFF314A61),
        onPrimaryContainer: Color(0xFFEAF5FF),
        secondary: Color(0xFF9AA8B6),
        onSecondary: Color(0xFF15202B),
        secondaryContainer: Color(0xFF2A3745),
        onSecondaryContainer: Color(0xFFE6EDF4),
        tertiary: Color(0xFF78FF7B),
        onTertiary: Color(0xFF102A16),
        tertiaryContainer: Color(0xFF3E618A),
        onTertiaryContainer: Colors.white,
        error: Color(0xFFFF6D6D),
        onError: Color(0xFF2B1010),
        errorContainer: Color(0xFF6E2B2B),
        onErrorContainer: Color(0xFFFFE9E9),
        surface: Color(0xFF1D2733),
        onSurface: Color(0xFFFAFAFA),
        onSurfaceVariant: Color(0xFF9AA8B6),
        surfaceDim: Color(0xFF151E27),
        surfaceBright: Color(0xFF354352),
        surfaceContainerLowest: Color(0xFF151E27),
        surfaceContainerLow: Color(0xFF212D3B),
        surfaceContainer: Color(0xFF242D39),
        surfaceContainerHigh: Color(0xFF232E3B),
        surfaceContainerHighest: Color(0xFF2A3745),
        outline: Color(0xFF5D7484),
        outlineVariant: Color(0xFF3B4B5B),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: Color(0xFFFAFAFA),
        onInverseSurface: Color(0xFF1D2733),
        inversePrimary: Color(0xFF1779B8),
        surfaceTint: Color(0xFF64B5EF),
      );
    }

    return const ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF229AF0),
      onPrimary: Color(0xFF102A3D),
      primaryContainer: Color(0xFFECF7FD),
      onPrimaryContainer: Color(0xFF174F78),
      secondary: Color(0xFF757575),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFF1F1F3),
      onSecondaryContainer: Color(0xFF1A1D21),
      tertiary: Color(0xFF26972C),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFEFFFDE),
      onTertiaryContainer: Color(0xFF1A1D21),
      error: Color(0xFFCC4747),
      onError: Colors.white,
      errorContainer: Color(0xFFFCE8E6),
      onErrorContainer: Color(0xFF7F1D1D),
      surface: Colors.white,
      onSurface: Color(0xFF1A1D21),
      onSurfaceVariant: Color(0xFF757575),
      surfaceDim: Color(0xFFF1F1F3),
      surfaceBright: Colors.white,
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Colors.white,
      surfaceContainer: Color(0xFFF7F7F7),
      surfaceContainerHigh: Colors.white,
      surfaceContainerHighest: Color(0xFFF1F1F3),
      outline: Color(0xFFB8BEC4),
      outlineVariant: Color(0xFFD9D9D9),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: Color(0xFF1A1D21),
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFF1677B8),
      surfaceTint: Color(0xFF229AF0),
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
        backgroundColor: scheme.surfaceContainer,
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
        shape: RoundedRectangleBorder(borderRadius: radius),
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
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(48, tokens.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: const StadiumBorder(),
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
          shape: const CircleBorder(),
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
        backgroundColor: scheme.surfaceContainer,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: const StadiumBorder(),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
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
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: dialogRadius,
          side: border,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: dialogRadius,
          side: border,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: dialogRadius,
          side: border,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
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
