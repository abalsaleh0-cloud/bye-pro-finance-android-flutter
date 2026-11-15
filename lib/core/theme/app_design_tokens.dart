import 'package:expense_app/core/theme/app_appearance.dart';
import 'package:material_ui/material_ui.dart';

/// Shared, non-color design values used by the whole application.
///
/// Color values stay in [ColorScheme]. Keeping geometry and motion here makes
/// the UI predictable when a user changes appearance settings.
class AppDesignTokens extends ThemeExtension<AppDesignTokens> {
  const AppDesignTokens({
    required this.pageHorizontalPadding,
    required this.pageVerticalPadding,
    required this.sectionSpacing,
    required this.cardRadius,
    required this.controlRadius,
    required this.dialogRadius,
    required this.cardElevation,
    required this.cardPadding,
    required this.listTileVerticalPadding,
    required this.inputVerticalPadding,
    required this.motionDuration,
  });

  /// Density is retained for backwards-compatible saved preferences, while
  /// geometry stays identical throughout every screen and component.
  factory AppDesignTokens.forDensity(AppDensity _) {
    return const AppDesignTokens(
      pageHorizontalPadding: 16,
      pageVerticalPadding: 10,
      sectionSpacing: 14,
      cardRadius: 24,
      controlRadius: 24,
      dialogRadius: 24,
      cardElevation: 0,
      cardPadding: 16,
      listTileVerticalPadding: 2,
      inputVerticalPadding: 14,
      motionDuration: Duration(milliseconds: 180),
    );
  }

  final double pageHorizontalPadding;
  final double pageVerticalPadding;
  final double sectionSpacing;
  final double cardRadius;
  final double controlRadius;
  final double dialogRadius;
  final double cardElevation;
  final double cardPadding;
  final double listTileVerticalPadding;
  final double inputVerticalPadding;
  final Duration motionDuration;

  @override
  AppDesignTokens copyWith({
    double? pageHorizontalPadding,
    double? pageVerticalPadding,
    double? sectionSpacing,
    double? cardRadius,
    double? controlRadius,
    double? dialogRadius,
    double? cardElevation,
    double? cardPadding,
    double? listTileVerticalPadding,
    double? inputVerticalPadding,
    Duration? motionDuration,
  }) {
    return AppDesignTokens(
      pageHorizontalPadding:
          pageHorizontalPadding ?? this.pageHorizontalPadding,
      pageVerticalPadding: pageVerticalPadding ?? this.pageVerticalPadding,
      sectionSpacing: sectionSpacing ?? this.sectionSpacing,
      cardRadius: cardRadius ?? this.cardRadius,
      controlRadius: controlRadius ?? this.controlRadius,
      dialogRadius: dialogRadius ?? this.dialogRadius,
      cardElevation: cardElevation ?? this.cardElevation,
      cardPadding: cardPadding ?? this.cardPadding,
      listTileVerticalPadding:
          listTileVerticalPadding ?? this.listTileVerticalPadding,
      inputVerticalPadding: inputVerticalPadding ?? this.inputVerticalPadding,
      motionDuration: motionDuration ?? this.motionDuration,
    );
  }

  @override
  AppDesignTokens lerp(
    covariant ThemeExtension<AppDesignTokens>? other,
    double t,
  ) {
    if (other is! AppDesignTokens) return this;

    return AppDesignTokens(
      pageHorizontalPadding:
          _lerp(pageHorizontalPadding, other.pageHorizontalPadding, t),
      pageVerticalPadding:
          _lerp(pageVerticalPadding, other.pageVerticalPadding, t),
      sectionSpacing: _lerp(sectionSpacing, other.sectionSpacing, t),
      cardRadius: _lerp(cardRadius, other.cardRadius, t),
      controlRadius: _lerp(controlRadius, other.controlRadius, t),
      dialogRadius: _lerp(dialogRadius, other.dialogRadius, t),
      cardElevation: _lerp(cardElevation, other.cardElevation, t),
      cardPadding: _lerp(cardPadding, other.cardPadding, t),
      listTileVerticalPadding:
          _lerp(listTileVerticalPadding, other.listTileVerticalPadding, t),
      inputVerticalPadding:
          _lerp(inputVerticalPadding, other.inputVerticalPadding, t),
      motionDuration: Duration(
        milliseconds: (motionDuration.inMilliseconds +
                (other.motionDuration.inMilliseconds -
                        motionDuration.inMilliseconds) *
                    t)
            .round(),
      ),
    );
  }

  static AppDesignTokens of(BuildContext context) {
    return Theme.of(context).extension<AppDesignTokens>() ??
        AppDesignTokens.forDensity(AppDensity.comfortable);
  }

  EdgeInsetsDirectional pageInsets({double? bottom}) {
    return EdgeInsetsDirectional.fromSTEB(
      pageHorizontalPadding,
      pageVerticalPadding,
      pageHorizontalPadding,
      bottom ?? pageVerticalPadding * 2,
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
