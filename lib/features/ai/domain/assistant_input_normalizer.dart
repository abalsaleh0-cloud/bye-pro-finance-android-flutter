import 'number_normalizer.dart';

/// Normalizes common Arabic spelling, dialect, punctuation, number and month
/// variants before intent matching. It does not make financial assumptions.
final class AssistantInputNormalizer {
  const AssistantInputNormalizer();

  static const _numbers = NumberNormalizer();

  static final _diacritics = RegExp(r'[\u064B-\u065F\u0670\u0640]');
  static final _nonWords = RegExp(r'[^0-9a-z\u0600-\u06FF]+');
  static final _spaces = RegExp(r'\s+');

  static const Map<String, int> _months = {
    'يناير': 1,
    'كانون الثاني': 1,
    'كانون التاني': 1,
    'فبراير': 2,
    'شباط': 2,
    'مارس': 3,
    'اذار': 3,
    'آذار': 3,
    'ابريل': 4,
    'نيسان': 4,
    'مايو': 5,
    'ايار': 5,
    'أيار': 5,
    'يونيو': 6,
    'حزيران': 6,
    'يوليو': 7,
    'تموز': 7,
    'اغسطس': 8,
    'أغسطس': 8,
    'اب': 8,
    'آب': 8,
    'سبتمبر': 9,
    'ايلول': 9,
    'أيلول': 9,
    'اكتوبر': 10,
    'أكتوبر': 10,
    'تشرين الاول': 10,
    'نوفمبر': 11,
    'تشرين الثاني': 11,
    'ديسمبر': 12,
    'كانون الاول': 12,
    'كانون الأول': 12,
  };

  String normalize(String input) {
    var value = _numbers.normalizeDigits(input).toLowerCase();
    value = value.replaceAll(_diacritics, '');
    value = value
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي');
    value = value.replaceAll(_nonWords, ' ');
    return value.replaceAll(_spaces, ' ').trim();
  }

  bool containsAny(String normalizedText, Iterable<String> phrases) {
    for (final phrase in phrases) {
      final normalizedPhrase = normalize(phrase);
      if (normalizedPhrase.isNotEmpty &&
          RegExp(
            '(^| )' + RegExp.escape(normalizedPhrase) + '( |$)',
          ).hasMatch(normalizedText)) {
        return true;
      }
    }
    return false;
  }

  int? extractAmount(String input) {
    var value = _numbers.normalizeDigits(input);
    value = value.replaceAll(
      RegExp(r'\b20\d{2}[-/](?:0?[1-9]|1[0-2])\b'),
      ' ',
    );
    value = value.replaceAll(
      RegExp(r'\b(?:0?[1-9]|1[0-2])[-/ ]20\d{2}\b'),
      ' ',
    );

    final numeric = RegExp(
      r'(?<![A-Za-z\u0600-\u06FF])([0-9]+(?:[,٬،][0-9]{3})*)(?![A-Za-z\u0600-\u06FF])',
    ).firstMatch(value);
    if (numeric != null) {
      return _numbers.parseInteger(numeric.group(1)!);
    }

    final normalized = normalize(value);
    final tokens = normalized.split(' ').where((item) => item.isNotEmpty).toList();
    int? best;
    var bestLength = 0;
    for (var start = 0; start < tokens.length; start++) {
      for (var end = start + 1;
          end <= tokens.length && end <= start + 7;
          end++) {
        final candidate = tokens.sublist(start, end).join(' ');
        final parsed = _numbers.parseInteger(candidate);
        if (parsed != null && end - start > bestLength) {
          best = parsed;
          bestLength = end - start;
        }
      }
    }
    return best;
  }

  (int, int)? extractMonth(
    String input, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final normalized = normalize(input);

    final yearFirst = RegExp(
      r'(?<!\d)(20\d{2})\s*[-/.]\s*(0?[1-9]|1[0-2])(?!\d)',
    ).firstMatch(normalized);
    if (yearFirst != null) {
      return (int.parse(yearFirst.group(1)!), int.parse(yearFirst.group(2)!));
    }

    final monthFirst = RegExp(
      r'(?<!\d)(0?[1-9]|1[0-2])\s*[-/.]\s*(20\d{2})(?!\d)',
    ).firstMatch(normalized);
    if (monthFirst != null) {
      return (int.parse(monthFirst.group(2)!), int.parse(monthFirst.group(1)!));
    }

    if (containsAny(normalized, const [
      'الشهر الماضي',
      'الشهر الفائت',
      'الشهر السابق',
      'الشهر اللي فات',
      'الشهر الذي فات',
      'قبل شهر',
    ])) {
      final previous = DateTime(now.year, now.month - 1);
      return (previous.year, previous.month);
    }

    if (containsAny(normalized, const [
      'الشهر القادم',
      'الشهر المقبل',
      'الشهر الجاي',
      'الشهر التالي',
    ])) {
      final next = DateTime(now.year, now.month + 1);
      return (next.year, next.month);
    }

    if (containsAny(normalized, const [
      'هذا الشهر',
      'هالشهر',
      'الشهر الحالي',
      'الشهر الجاري',
      'الشهر الحاليه',
    ])) {
      return (now.year, now.month);
    }

    final words = _months.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final entry in words) {
      final monthName = normalize(entry.key);
      if (RegExp(
        '(^| )' + RegExp.escape(monthName) + '( |$)',
      ).hasMatch(normalized)) {
        final year = RegExp(r'(?<!\d)(20\d{2})(?!\d)')
            .firstMatch(normalized)
            ?.group(1);
        return (year == null ? now.year : int.parse(year), entry.value);
      }
    }

    final numericMonth = RegExp(
      r'(?:شهر|الشهر)\s+(0?[1-9]|1[0-2])(?:\s+(?:لسنة|سنة|عام)\s+(20\d{2}))?',
    ).firstMatch(normalized);
    if (numericMonth != null) {
      final year = numericMonth.group(2);
      return (year == null ? now.year : int.parse(year), int.parse(numericMonth.group(1)!));
    }

    return null;
  }
}
