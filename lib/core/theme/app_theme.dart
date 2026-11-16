import 'package:expense_app/core/theme/app_appearance.dart';
import 'package:expense_app/core/theme/app_design_tokens.dart';
import 'package:material_ui/material_ui.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light => lightFor(builtInThemePresets.first);
  static ThemeData get dark => darkFor(builtInThemePresets.first);

  static ThemeData lightFor(AppThemePreset preset) => _buildTheme(
        preset,
        isDark: false,
      );

  static ThemeData darkFor(AppThemePreset preset) => _buildTheme(
        preset,
        isDark: true,
      );

  static ColorScheme colorSchemeFor(
    AppThemePreset preset, {
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final h = preset.hue % 360;
    final h2 = preset.accentHue % 360;
    final surfaceSaturation = (preset.chroma * 1.15).clamp(.005, .16);
    final accentSaturation = (preset.accentChroma * 4.1).clamp(.16, .86);
    final secondarySaturation =
        (preset.accentChroma * 3.7).clamp(.14, .78);

    Color tone(double hue, double saturation, double lightness) =>
        HSLColor.fromAHSL(
          1,
          (hue % 360 + 360) % 360,
          saturation,
          lightness,
        ).toColor();

    final background = tone(h, surfaceSaturation, isDark ? .105 : .975);
    final surface = tone(h, surfaceSaturation, isDark ? .145 : .925);
    final surfaceRaised = tone(h, surfaceSaturation, isDark ? .19 : .875);
    final text = tone(h, .035, isDark ? .955 : .20);
    final mutedText = tone(h, .035, isDark ? .74 : .40);
    final primary = tone(h2, accentSaturation, isDark ? .73 : .43);
    final secondary = tone(
      h2 + preset.hueOffset,
      secondarySaturation,
      isDark ? .78 : .48,
    );
    final tertiary = tone(
      h2 + preset.hueOffset + 110,
      (accentSaturation * .72).clamp(.12, .65),
      isDark ? .72 : .42,
    );
    final generated = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: isDark ? Brightness.dark : Brightness.light,
    );

    return generated.copyWith(
      primary: primary,
      onPrimary: _bestContentColor(primary),
      primaryContainer:
          tone(h2, accentSaturation * .42, isDark ? .30 : .88),
      onPrimaryContainer:
          isDark ? Colors.white : tone(h2, .48, .20),
      secondary: secondary,
      onSecondary: _bestContentColor(secondary),
      secondaryContainer: tone(
        h2 + preset.hueOffset,
        secondarySaturation * .38,
        isDark ? .29 : .89,
      ),
      onSecondaryContainer:
          isDark ? Colors.white : tone(h2 + preset.hueOffset, .42, .20),
      tertiary: tertiary,
      onTertiary: _bestContentColor(tertiary),
      surface: surface,
      onSurface: text,
      surfaceDim: background,
      surfaceBright: tone(h, surfaceSaturation, isDark ? .23 : .99),
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: surface,
      surfaceContainerHigh: surfaceRaised,
      surfaceContainerHighest:
          tone(h, surfaceSaturation, isDark ? .235 : .84),
      outline: mutedText,
      outlineVariant:
          tone(h, surfaceSaturation * .85, isDark ? .32 : .79),
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }

  static Color _bestContentColor(Color background) {
    final whiteContrast = contrastRatio(Colors.white, background);
    final blackContrast = contrastRatio(Colors.black, background);
    return whiteContrast >= blackContrast ? Colors.white : Colors.black;
  }

  static ThemeData _buildTheme(
    AppThemePreset preset, {
    required bool isDark,
  }) {
    final scheme = colorSchemeFor(
      preset,
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
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: scheme.surfaceContainerLow,
      textTheme: Typography.material2021(
        platform: TargetPlatform.android,
        colorScheme: scheme,
      ).black.apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface.withValues(alpha: .92),
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
        color: scheme.surfaceContainerLow.withValues(alpha: .91),
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
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
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
          side: border,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
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
        height: 72,
        backgroundColor: scheme.surface.withValues(alpha: .96),
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
