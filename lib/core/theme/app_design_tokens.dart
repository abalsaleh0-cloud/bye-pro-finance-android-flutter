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
    required this.buttonHeight,
    required this.touchTargetSize,
    required this.navigationBarHeight,
    required this.sectionTabHeight,
    required this.metricTileMinHeight,
    required this.recordIconBoxSize,
    required this.standardIconSize,
  });

  factory AppDesignTokens.standard() => const AppDesignTokens(
        pageHorizontalPadding: 16,
        pageVerticalPadding: 12,
        sectionSpacing: 12,
        cardRadius: 16,
        controlRadius: 12,
        dialogRadius: 20,
        cardElevation: 0,
        cardPadding: 16,
        listTileVerticalPadding: 2,
        inputVerticalPadding: 12,
        motionDuration: Duration(milliseconds: 160),
        buttonHeight: 48,
        touchTargetSize: 44,
        navigationBarHeight: 68,
        sectionTabHeight: 48,
        metricTileMinHeight: 96,
        recordIconBoxSize: 40,
        standardIconSize: 20,
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
  final double buttonHeight;
  final double touchTargetSize;
  final double navigationBarHeight;
  final double sectionTabHeight;
  final double metricTileMinHeight;
  final double recordIconBoxSize;
  final double standardIconSize;

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
    double? buttonHeight,
    double? touchTargetSize,
    double? navigationBarHeight,
    double? sectionTabHeight,
    double? metricTileMinHeight,
    double? recordIconBoxSize,
    double? standardIconSize,
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
      buttonHeight: buttonHeight ?? this.buttonHeight,
      touchTargetSize: touchTargetSize ?? this.touchTargetSize,
      navigationBarHeight: navigationBarHeight ?? this.navigationBarHeight,
      sectionTabHeight: sectionTabHeight ?? this.sectionTabHeight,
      metricTileMinHeight: metricTileMinHeight ?? this.metricTileMinHeight,
      recordIconBoxSize: recordIconBoxSize ?? this.recordIconBoxSize,
      standardIconSize: standardIconSize ?? this.standardIconSize,
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
      buttonHeight: d(buttonHeight, other.buttonHeight),
      touchTargetSize: d(touchTargetSize, other.touchTargetSize),
      navigationBarHeight: d(navigationBarHeight, other.navigationBarHeight),
      sectionTabHeight: d(sectionTabHeight, other.sectionTabHeight),
      metricTileMinHeight:
          d(metricTileMinHeight, other.metricTileMinHeight),
      recordIconBoxSize: d(recordIconBoxSize, other.recordIconBoxSize),
      standardIconSize: d(standardIconSize, other.standardIconSize),
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
