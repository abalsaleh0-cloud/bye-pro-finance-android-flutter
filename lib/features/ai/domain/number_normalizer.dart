/// Converts Arabic/Persian digits and common Arabic number words to integers.
final class NumberNormalizer {
  const NumberNormalizer();

  static const Map<int, String> _digits = {
    0x0660: '0', 0x0661: '1', 0x0662: '2', 0x0663: '3', 0x0664: '4',
    0x0665: '5', 0x0666: '6', 0x0667: '7', 0x0668: '8', 0x0669: '9',
    0x06F0: '0', 0x06F1: '1', 0x06F2: '2', 0x06F3: '3', 0x06F4: '4',
    0x06F5: '5', 0x06F6: '6', 0x06F7: '7', 0x06F8: '8', 0x06F9: '9',
  };

  static const Map<String, int> _units = {
    'صفر': 0,
    'واحد': 1, 'واحدة': 1, 'احد': 1, 'احدى': 1,
    'اثنان': 2, 'اثنين': 2, 'اثنا': 2, 'اتنين': 2,
    'ثلاثة': 3, 'ثلاث': 3, 'تلاتة': 3, 'تلات': 3,
    'اربعة': 4, 'اربعه': 4, 'اربَع': 4,
    'خمسة': 5, 'خمس': 5,
    'ستة': 6, 'سته': 6, 'ست': 6,
    'سبعة': 7, 'سبعه': 7, 'سبع': 7,
    'ثمانية': 8, 'تمانية': 8, 'ثمان': 8,
    'تسعة': 9, 'تسعه': 9, 'تسع': 9,
    'عشرة': 10, 'عشره': 10, 'عشر': 10,
    'احدعشر': 11, 'حدعش': 11,
    'اتناشر': 12,
    'تلتعش': 13,
    'اربعتعش': 14,
    'خمستعش': 15,
    'ستعش': 16,
    'سبعتعش': 17,
    'تمنتعش': 18,
    'تسعتعش': 19,
  };

  static const Map<String, int> _tens = {
    'عشرين': 20, 'عشرون': 20, 'عشره': 10,
    'ثلاثين': 30, 'ثلاثون': 30, 'تلاتين': 30,
    'اربعين': 40, 'أربعين': 40, 'اربعون': 40,
    'خمسين': 50, 'خمسون': 50,
    'ستين': 60, 'ستون': 60,
    'سبعين': 70, 'سبعون': 70,
    'ثمانين': 80, 'ثمانون': 80,
    'تسعين': 90, 'تسعون': 90,
  };

  static const Map<String, int> _hundreds = {
    'مئة': 100, 'مائة': 100, 'مائه': 100, 'ميه': 100, 'مية': 100, 'ماية': 100,
    'مئتين': 200, 'مائتين': 200, 'ميتين': 200,
    'ثلاثمئة': 300, 'ثلاثمائه': 300, 'تلتمية': 300, 'ثلاثمية': 300,
    'اربعمئة': 400, 'اربعمائه': 400, 'اربعمية': 400, 'اربماية': 400,
    'خمسمئة': 500, 'خمسمائة': 500, 'خمسمائه': 500, 'خمسمية': 500, 'خمسمائية': 500,
    'ستمئة': 600, 'ستمائه': 600, 'ستمية': 600, 'ستماية': 600,
    'سبعمئة': 700, 'سبعمائه': 700, 'سبعمية': 700, 'سبعماية': 700,
    'ثمانمئة': 800, 'ثمانمائه': 800, 'تمنمية': 800, 'تمنماية': 800,
    'تسعمئة': 900, 'تسعمائه': 900, 'تسعمية': 900, 'تسعماية': 900,
  };

  static const Map<String, int> _scales = {
    'الف': 1000,
    'ألف': 1000,
    'الاف': 1000,
    'آلاف': 1000,
    'الفين': 2000,
    'ألفين': 2000,
    'مليون': 1000000,
    'مليونين': 2000000,
    'ملايين': 1000000,
  };

  String normalizeDigits(String input) => String.fromCharCodes(
        input.runes.map((r) => _digits[r]?.codeUnitAt(0) ?? r),
      );

  String normalize(String input) => normalizeDigits(input);

  String _normalizeNumberWords(String input) {
    return input
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
        .replaceAll(RegExp('[أإآٱ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  int? parseInteger(String input) {
    final value = normalizeDigits(input)
        .trim()
        .replaceAll(',', '')
        .replaceAll('٬', '')
        .replaceAll('،', '');
    final numeric = int.tryParse(value);
    if (numeric != null && numeric >= 0) return numeric;

    final normalized = _normalizeNumberWords(value);
    if (normalized.isEmpty) return null;

    final tokens = normalized
        .replaceAll(RegExp(r'\s+و(?=\S)'), ' ')
        .split(' ')
        .where((token) => token.isNotEmpty && token != 'و')
        .toList(growable: false);
    if (tokens.isEmpty) return null;

    var total = 0;
    var group = 0;

    for (var token in tokens) {
      if (token.startsWith('و') &&
          token.length > 1 &&
          !_units.containsKey(token)) {
        final withoutConjunction = token.substring(1);
        if (_units.containsKey(withoutConjunction) ||
            _tens.containsKey(withoutConjunction) ||
            _hundreds.containsKey(withoutConjunction) ||
            _scales.containsKey(withoutConjunction)) {
          token = withoutConjunction;
        }
      }

      final numericToken = int.tryParse(token);
      final unit = _units[token];
      final ten = _tens[token];
      final hundred = _hundreds[token];
      final scale = _scales[token];

      if (numericToken != null && numericToken >= 0) {
        group += numericToken;
      } else if (unit != null) {
        group += unit;
      } else if (ten != null) {
        group += ten;
      } else if (hundred != null) {
        group += hundred;
      } else if (scale != null) {
        if (scale == 2000 || scale == 2000000) {
          total += scale;
        } else {
          total += (group == 0 ? 1 : group) * scale;
        }
        group = 0;
      } else {
        return null;
      }
    }

    final result = total + group;
    return result >= 0 ? result : null;
  }
}
