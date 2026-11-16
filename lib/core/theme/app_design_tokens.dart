import 'package:material_ui/material_ui.dart';

/// Geometry tokens are intentionally fixed so switching themes never changes
/// component sizes, spacing, or touch targets across the five app sections.
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

  factory AppDesignTokens.standard() => const AppDesignTokens(
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
    double d(double a, double b) => a + (b - a) * t;
    return AppDesignTokens(
      pageHorizontalPadding:
          d(pageHorizontalPadding, other.pageHorizontalPadding),
      pageVerticalPadding: d(pageVerticalPadding, other.pageVerticalPadding),
      sectionSpacing: d(sectionSpacing, other.sectionSpacing),
      cardRadius: d(cardRadius, other.cardRadius),
      controlRadius: d(controlRadius, other.controlRadius),
      dialogRadius: d(dialogRadius, other.dialogRadius),
      cardElevation: d(cardElevation, other.cardElevation),
      cardPadding: d(cardPadding, other.cardPadding),
      listTileVerticalPadding:
          d(listTileVerticalPadding, other.listTileVerticalPadding),
      inputVerticalPadding:
          d(inputVerticalPadding, other.inputVerticalPadding),
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
        AppDesignTokens.standard();
  }

  EdgeInsetsDirectional pageInsets({double? bottom}) {
    return EdgeInsetsDirectional.fromSTEB(
      pageHorizontalPadding,
      pageVerticalPadding,
      pageHorizontalPadding,
      bottom ?? pageVerticalPadding * 2,
    );
  }
}
