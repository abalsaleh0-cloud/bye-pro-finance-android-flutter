/// Shared calendar formatting helpers used by every financial section.
String formatCalendarDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

/// Converts Arabic-Indic and Eastern Arabic-Indic digits to ASCII digits.
String toAsciiDigits(String value) {
  return value.replaceAllMapped(RegExp(r'[٠-٩۰-۹]'), (match) {
    final codePoint = match.group(0)!.runes.single;
    final digit = codePoint >= 0x06f0 ? codePoint - 0x06f0 : codePoint - 0x0660;
    return digit.toString();
  });
}
