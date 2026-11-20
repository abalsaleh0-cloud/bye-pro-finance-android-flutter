import 'package:material_ui/material_ui.dart';

/// Formats an integer amount using the active locale without assuming a
/// currency symbol or changing the stored minor-unit value.
String formatMinorUnits(BuildContext context, int amount) =>
    MaterialLocalizations.of(context).formatDecimal(amount);
